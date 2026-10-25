using NaRotta.MapBuilder.Core.Logging;
using NaRotta.MapBuilder.Core.Models;
using System.Collections.Generic;
using System.IO;
using Xunit;

namespace NaRotta.MapBuilder.Tests {
    /// <summary>
    /// Unit tests verifying <see cref="BufferedConsoleWriter"/> decoration, log level parsing, and buffer forwarding.
    /// </summary>
    public class BufferedConsoleWriterTests {
        [Fact]
        public void WriteLine_ForwardsToBothInnerWriterAndLogBuffer() {
            var stringWriter = new StringWriter();
            var logBuffer = new BuildLogBuffer(100);
            using var writer = new BufferedConsoleWriter(stringWriter, logBuffer, "INFO");

            writer.WriteLine("Sample console log line");

            string consoleOutput = stringWriter.ToString();
            Assert.Contains("Sample console log line", consoleOutput);

            List<BuildLogEntryModel> entryList = logBuffer.GetRecentEntryList(10);
            Assert.Single(entryList);
            Assert.Equal("Sample console log line", entryList[0].Message);
            Assert.Equal("INFO", entryList[0].Level);
        }

        [Fact]
        public void WriteLine_DetectsLogLevelsCorrectly() {
            var stringWriter = new StringWriter();
            var logBuffer = new BuildLogBuffer(100);
            using var writer = new BufferedConsoleWriter(stringWriter, logBuffer, "INFO");

            writer.WriteLine("0:00:00 DEB - argument: schema=schema.yml");
            writer.WriteLine("0:00:01 INF [osm_pass1] reading nodes");
            writer.WriteLine("0:00:05 WRN [geometry] polygon self-intersection");
            writer.WriteLine("fail: Database connection lost");

            List<BuildLogEntryModel> entryList = logBuffer.GetRecentEntryList(10);
            Assert.Equal(4, entryList.Count);
            Assert.Equal("DEBUG", entryList[0].Level);
            Assert.Equal("INFO", entryList[1].Level);
            Assert.Equal("WARN", entryList[2].Level);
            Assert.Equal("ERROR", entryList[3].Level);
        }

        [Fact]
        public void WriteLine_FiltersKestrelHeaderRemovalWarning() {
            var stringWriter = new StringWriter();
            var logBuffer = new BuildLogBuffer(100);
            using var writer = new BufferedConsoleWriter(stringWriter, logBuffer, "INFO");

            writer.WriteLine("warn: Microsoft.AspNetCore.Server.Kestrel[41] One or more of the following response headers have been removed because they are invalid for HTTP/2 and HTTP/3 responses");
            writer.WriteLine("Valid application log line");

            // Inner writer gets everything
            string consoleOutput = stringWriter.ToString();
            Assert.Contains("Microsoft.AspNetCore.Server.Kestrel", consoleOutput);

            // Buffer only gets valid application line
            List<BuildLogEntryModel> entryList = logBuffer.GetRecentEntryList(10);
            Assert.Single(entryList);
            Assert.Equal("Valid application log line", entryList[0].Message);
        }

        [Fact]
        public void WriteLine_SplitsMultilineOutputIntoSeparateLogEntries() {
            var stringWriter = new StringWriter();
            var logBuffer = new BuildLogBuffer(100);
            using var writer = new BufferedConsoleWriter(stringWriter, logBuffer, "INFO");

            writer.WriteLine("Line 1\nLine 2\r\nLine 3");

            List<BuildLogEntryModel> entryList = logBuffer.GetRecentEntryList(10);
            Assert.Equal(3, entryList.Count);
            Assert.Equal("Line 1", entryList[0].Message);
            Assert.Equal("Line 2", entryList[1].Message);
            Assert.Equal("Line 3", entryList[2].Message);
        }

        [Fact]
        public void WriteLine_WhenActiveRegionAndStageConfigured_TagsLogEntries() {
            var stringWriter = new StringWriter();
            var logBuffer = new BuildLogBuffer(100) {
                ActiveRegionId = "andorra",
                ActiveStageName = "BuildingTilesBase"
            };
            using var writer = new BufferedConsoleWriter(stringWriter, logBuffer, "INFO");

            writer.WriteLine("0:00:02 INF [archive:write] 100 tiles written");

            List<BuildLogEntryModel> entryList = logBuffer.GetRecentEntryList(10);
            Assert.Single(entryList);
            Assert.Equal("andorra", entryList[0].RegionId);
            Assert.Equal("BuildingTilesBase", entryList[0].StageName);
        }
    }
}
