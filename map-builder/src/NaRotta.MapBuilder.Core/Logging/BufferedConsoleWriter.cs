using NaRotta.MapBuilder.Core.Models;
using System;
using System.IO;
using System.Text;
using System.Threading.Tasks;

namespace NaRotta.MapBuilder.Core.Logging {
    /// <summary>
    /// Thread-safe <see cref="TextWriter"/> decorator that forwards console writes to both the
    /// inner terminal writer and the in-memory <see cref="BuildLogBuffer"/> for web dashboard streaming.
    /// </summary>
    public class BufferedConsoleWriter : TextWriter {
        private readonly TextWriter _innerWriter;
        private readonly BuildLogBuffer _logBuffer;
        private readonly string _defaultLevel;
        private readonly object _syncLock = new object();

        [ThreadStatic]
        private static bool _isForwarding;

        public BufferedConsoleWriter(TextWriter innerWriter, BuildLogBuffer logBuffer, string defaultLevel = "INFO") {
            _innerWriter = innerWriter;
            _logBuffer = logBuffer;
            _defaultLevel = defaultLevel;
        }

        public override Encoding Encoding {
            get {
                return _innerWriter.Encoding;
            }
        }

        public override void WriteLine(string? value) {
            lock (_syncLock) {
                _innerWriter.WriteLine(value);
            }

            if (string.IsNullOrWhiteSpace(value)) {
                return;
            }

            if (_isForwarding) {
                return;
            }

            // Suppress Kestrel HTTP/2 response header warnings from spamming web build logs
            if (value.Contains("Microsoft.AspNetCore.Server.Kestrel", StringComparison.OrdinalIgnoreCase) ||
                value.Contains("invalid for HTTP/2 and HTTP/3 responses", StringComparison.OrdinalIgnoreCase)) {
                return;
            }

            try {
                _isForwarding = true;

                if (value.Contains('\n')) {
                    string[] lineList = value.Split(new string[] { "\r\n", "\r", "\n" }, StringSplitOptions.None);
                    foreach (string lineItem in lineList) {
                        if (!string.IsNullOrWhiteSpace(lineItem)) {
                            ForwardLine(lineItem);
                        }
                    }
                }else {
                    ForwardLine(value);
                }
            }finally {
                _isForwarding = false;
            }
        }

        public override void WriteLine() {
            lock (_syncLock) {
                _innerWriter.WriteLine();
            }
        }

        public override void Write(char value) {
            lock (_syncLock) {
                _innerWriter.Write(value);
            }
        }

        public override void Write(string? value) {
            lock (_syncLock) {
                _innerWriter.Write(value);
            }
        }

        public override void Flush() {
            lock (_syncLock) {
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

        private void ForwardLine(string line) {
            string level = DetectLogLevel(line, _defaultLevel);
            _logBuffer.AppendLog(line, level);
        }

        private static string DetectLogLevel(string message, string defaultLevel) {
            if (message.Contains(" ERR ") || message.Contains("[ERR]") || message.Contains("[ERROR]") ||
                message.StartsWith("fail:", StringComparison.OrdinalIgnoreCase) ||
                message.StartsWith("error:", StringComparison.OrdinalIgnoreCase)) {
                return "ERROR";
            }

            if (message.Contains(" WRN ") || message.Contains("[WRN]") || message.Contains("[WARN]") ||
                message.StartsWith("warn:", StringComparison.OrdinalIgnoreCase)) {
                return "WARN";
            }

            if (message.Contains(" DEB ") || message.Contains("[DEB]") || message.Contains("[DEBUG]") ||
                message.StartsWith("dbug:", StringComparison.OrdinalIgnoreCase)) {
                return "DEBUG";
            }

            return defaultLevel;
        }
    }
}
