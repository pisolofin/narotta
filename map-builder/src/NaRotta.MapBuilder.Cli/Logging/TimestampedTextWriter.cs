using System;
using System.Globalization;
using System.IO;
using System.Text;
using System.Threading.Tasks;

namespace NaRotta.MapBuilder.Cli.Logging {
    /// <summary>
    /// Thread-safe <see cref="TextWriter"/> decorator that prefixes each non-empty line with a local ISO-like timestamp [yyyy-MM-dd HH:mm:ss]
    /// and optional region progress indicator [current/total].
    /// </summary>
    public class TimestampedTextWriter : TextWriter {
        private readonly TextWriter _innerWriter;
        private readonly object _lockObject = new object();

        /// <summary>
        /// Gets or sets the current region progress indicator (e.g. "15/261") or null when no batch is active.
        /// </summary>
        public static string? CurrentRegionProgress { get; set; }

        public TimestampedTextWriter(TextWriter innerWriter) {
            _innerWriter = innerWriter;
        }

        public override Encoding Encoding {
            get {
                return _innerWriter.Encoding;
            }
        }

        /// <summary>
        /// Writes a string followed by a line terminator, prefixing non-empty lines with a timestamp and optional region progress.
        /// </summary>
        public override void WriteLine(string? value) {
            if (string.IsNullOrWhiteSpace(value)) {
                lock (_lockObject) {
                    _innerWriter.WriteLine(value);
                }
                return;
            }

            string timestamp = DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss", CultureInfo.InvariantCulture);
            string? progress = CurrentRegionProgress;
            string progressPrefix = string.IsNullOrEmpty(progress) ? string.Empty : (" [" + progress + "]");

            lock (_lockObject) {
                _innerWriter.WriteLine("[" + timestamp + "]" + progressPrefix + " " + value);
            }
        }

        public override void WriteLine() {
            lock (_lockObject) {
                _innerWriter.WriteLine();
            }
        }

        public override void Write(char value) {
            lock (_lockObject) {
                _innerWriter.Write(value);
            }
        }

        public override void Write(string? value) {
            lock (_lockObject) {
                _innerWriter.Write(value);
            }
        }

        public override void Flush() {
            lock (_lockObject) {
                _innerWriter.Flush();
            }
        }

        public override Task FlushAsync() {
            return _innerWriter.FlushAsync();
        }

        protected override void Dispose(bool disposing) {
            if (disposing) {
                _innerWriter.Dispose();
            }
            base.Dispose(disposing);
        }
    }
}
