using NaRotta.MapBuilder.Core.Logging;
using System.IO;
using Xunit;

namespace NaRotta.MapBuilder.Tests {
    /// <summary>
    /// Unit tests verifying timestamp formatting and batch progress prefixing in <see cref="TimestampedTextWriter"/>.
    /// </summary>
    public class TimestampedTextWriterTests {
        [Fact]
        public void WriteLine_WhenNoRegionProgressSet_PrefixesWithTimestampOnly() {
            // Arrange
            TimestampedTextWriter.CurrentRegionProgress = null;
            using var stringWriter = new StringWriter();
            using var timestampedWriter = new TimestampedTextWriter(stringWriter);

            // Act
            timestampedWriter.WriteLine("Starting operation");
            string output = stringWriter.ToString();

            // Assert
            Assert.Contains("] Starting operation", output);
            Assert.DoesNotContain("[/", output);
        }

        [Fact]
        public void WriteLine_WhenRegionProgressSet_PrefixesWithTimestampAndRegionCount() {
            // Arrange
            TimestampedTextWriter.CurrentRegionProgress = "15/261";
            using var stringWriter = new StringWriter();
            using var timestampedWriter = new TimestampedTextWriter(stringWriter);

            try {
                // Act
                timestampedWriter.WriteLine("[Download] Starting download");
                string output = stringWriter.ToString();

                // Assert
                Assert.Contains("] [15/261] [Download] Starting download", output);
            }finally {
                TimestampedTextWriter.CurrentRegionProgress = null;
            }
        }

        [Fact]
        public void WriteLine_WhenWhitespaceOnly_DoesNotAddPrefix() {
            // Arrange
            TimestampedTextWriter.CurrentRegionProgress = "15/261";
            using var stringWriter = new StringWriter();
            using var timestampedWriter = new TimestampedTextWriter(stringWriter);

            try {
                // Act
                timestampedWriter.WriteLine("");
                string output = stringWriter.ToString();

                // Assert
                Assert.DoesNotContain("[15/261]", output);
            }finally {
                TimestampedTextWriter.CurrentRegionProgress = null;
            }
        }
    }
}
