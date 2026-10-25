using NaRotta.MapBuilder.Core.Logging;
using NaRotta.MapBuilder.Core.Models;
using System;
using System.Collections.Generic;
using System.Threading;
using System.Threading.Channels;
using System.Threading.Tasks;
using Xunit;

namespace NaRotta.MapBuilder.Tests {
    /// <summary>
    /// Unit tests verifying the thread-safe circular log buffer and streaming subscription channels.
    /// </summary>
    public class BuildLogBufferTests {
        [Fact]
        public void AppendLog_WhenLogAppended_GeneratesMonotonicSequenceNumbers() {
            var buffer = new BuildLogBuffer(100);

            BuildLogEntryModel entry1 = buffer.AppendLog("Message 1", "INFO");
            BuildLogEntryModel entry2 = buffer.AppendLog("Message 2", "WARN");

            Assert.True(entry2.SequenceNumber > entry1.SequenceNumber);
            Assert.Equal("Message 1", entry1.Message);
            Assert.Equal("WARN", entry2.Level);
        }

        [Fact]
        public void AppendLog_WhenCapacityExceeded_TrimsOldestEntries() {
            var buffer = new BuildLogBuffer(3);

            buffer.AppendLog("Log 1");
            buffer.AppendLog("Log 2");
            buffer.AppendLog("Log 3");
            buffer.AppendLog("Log 4");

            List<BuildLogEntryModel> recentList = buffer.GetRecentEntryList(10);
            Assert.Equal(3, recentList.Count);
            Assert.Equal("Log 2", recentList[0].Message);
            Assert.Equal("Log 3", recentList[1].Message);
            Assert.Equal("Log 4", recentList[2].Message);
        }

        [Fact]
        public async Task Subscribe_WhenSubscribed_ReceivesLiveStreamEntriesAsync() {
            var buffer = new BuildLogBuffer(50);
            using var cts = new CancellationTokenSource();

            ChannelReader<BuildLogEntryModel> reader = buffer.Subscribe(cts.Token, out Guid subscriberId);

            buffer.AppendLog("Live log test", "INFO");

            BuildLogEntryModel received = await reader.ReadAsync(cts.Token);
            Assert.Equal("Live log test", received.Message);

            buffer.Unsubscribe(subscriberId);
        }
    }
}
