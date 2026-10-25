using NaRotta.MapBuilder.Core.Models;
using System;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Linq;
using System.Threading;
using System.Threading.Channels;

namespace NaRotta.MapBuilder.Core.Logging {
    /// <summary>
    /// Thread-safe in-memory ring buffer for streaming and capturing build logs.
    /// Provides real-time subscription channels for Server-Sent Events (SSE) and WebSockets.
    /// </summary>
    public class BuildLogBuffer {
        private readonly int _maxCapacity;
        private readonly object _syncLock = new object();
        private readonly LinkedList<BuildLogEntryModel> _logEntryList = new LinkedList<BuildLogEntryModel>();
        private readonly ConcurrentDictionary<Guid, Channel<BuildLogEntryModel>> _subscriberChannelDictionary = new ConcurrentDictionary<Guid, Channel<BuildLogEntryModel>>();
        private long _sequenceCounter = 0;

        public string? ActiveRegionId { get; set; }
        public string? ActiveStageName { get; set; }

        public event Action<BuildLogEntryModel>? OnLogAppended;

        public BuildLogBuffer(int maxCapacity = 5000) {
            _maxCapacity = maxCapacity;
        }

        /// <summary>
        /// Appends a new structured log entry, trims oldest logs if capacity is exceeded, and broadcasts to active subscribers.
        /// </summary>
        public BuildLogEntryModel AppendLog(string message, string level = "INFO", string? regionId = null, string? stageName = null) {
            long sequenceNumber = Interlocked.Increment(ref _sequenceCounter);
            string? effectiveRegionId = regionId ?? this.ActiveRegionId;
            string? effectiveStageName = stageName ?? this.ActiveStageName;
            var entry = new BuildLogEntryModel(sequenceNumber, level, message, effectiveRegionId, effectiveStageName);

            lock (_syncLock) {
                _logEntryList.AddLast(entry);
                while (_logEntryList.Count > _maxCapacity) {
                    _logEntryList.RemoveFirst();
                }
            }

            // Notify in-process listeners
            try {
                this.OnLogAppended?.Invoke(entry);
            }catch {
                // Ignore listener exceptions to protect logger integrity
            }

            // Push to connected web subscribers (SSE streams)
            foreach (KeyValuePair<Guid, Channel<BuildLogEntryModel>> pair in _subscriberChannelDictionary) {
                pair.Value.Writer.TryWrite(entry);
            }

            return entry;
        }

        /// <summary>
        /// Retrieves the most recent log entries up to <paramref name="maxCount"/>.
        /// </summary>
        public List<BuildLogEntryModel> GetRecentEntryList(int maxCount = 500) {
            lock (_syncLock) {
                if (maxCount <= 0) {
                    return new List<BuildLogEntryModel>();
                }

                int countToTake = Math.Min(maxCount, _logEntryList.Count);
                return _logEntryList.Skip(_logEntryList.Count - countToTake).ToList();
            }
        }

        /// <summary>
        /// Subscribes to new log entries via an unbounded asynchronous channel.
        /// </summary>
        public ChannelReader<BuildLogEntryModel> Subscribe(CancellationToken cancellationToken, out Guid subscriberId) {
            subscriberId = Guid.NewGuid();
            Guid registeredId = subscriberId;
            var channel = Channel.CreateUnbounded<BuildLogEntryModel>(new UnboundedChannelOptions {
                SingleWriter = false,
                SingleReader = true
            });

            _subscriberChannelDictionary[registeredId] = channel;

            // Automatically remove channel when token is cancelled
            cancellationToken.Register(() => {
                Unsubscribe(registeredId);
            });

            return channel.Reader;
        }

        /// <summary>
        /// Removes an active subscriber channel.
        /// </summary>
        public void Unsubscribe(Guid subscriberId) {
            if (_subscriberChannelDictionary.TryRemove(subscriberId, out Channel<BuildLogEntryModel>? channel)) {
                channel.Writer.TryComplete();
            }
        }

        /// <summary>
        /// Clears all buffered log lines and resets the sequence counter.
        /// </summary>
        public void Clear() {
            lock (_syncLock) {
                _logEntryList.Clear();
            }
        }
    }
}
