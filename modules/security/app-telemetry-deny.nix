{ pkgs, ... }:
{
  # App Telemetry Denial Module
  # Conservative approach - only block actual telemetry endpoints
  networking.hosts = {
    "0.0.0.0" = [
      # AI assistants — deliberate policy, not telemetry; owned here
      "copilot-proxy.githubusercontent.com"
      "api.githubcopilot.com"
      "cloud.tabnine.com"
      "api.tabnine.com"
      "server.codeium.com"
      "api.codeium.com"
      "api.cursor.sh"
      "cursor.sh"
      "codewhisperer.aws.amazon.com"
      "ai.jetbrains.com"
      "ai-assistant.jetbrains.com"
      # App telemetry not covered by community lists
      "crash-reports.slack.com"
      "telemetry.slack.com"
      "stats.slack.com"
      "analytics.slack.com"
      "telemetry.teams.microsoft.com"
      "watson.telemetry.microsoft.com"
      "vortex.data.microsoft.com"
      "browser.events.data.microsoft.com"
      "mobile.events.data.microsoft.com"
      "telemetry.microsoft.com"
      "sqm.telemetry.microsoft.com"
	  "logfiles.zoom.us"
      "events.zoom.us"
      "analytics.zoom.us"
      "crashdump.spotify.com"
      "google-analytics.com"
      "www.google-analytics.com"
      "ssl.google-analytics.com"
      "region1.google-analytics.com"
      "analytics.google.com"
      "api.segment.io"
      "cdn.segment.com"
    ];
  };

  environment.variables = {
    SLACK_DISABLE_TELEMETRY = "1";
    TEAMS_DISABLE_TELEMETRY = "1";
    ZOOM_DISABLE_ANALYTICS = "1";
    DOTNET_CLI_TELEMETRY_OPTOUT = "1";
    VSCODE_TELEMETRY_LEVEL = "off";
    NEXT_TELEMETRY_DISABLED = "1";
    ELECTRON_DISABLE_CRASH_REPORTER = "1";
    NPM_CONFIG_DISABLE_UPDATE_NOTIFIER = "true";
    ZOOM_DISABLE_TELEMETRY = "1";
    LO_JAVA_JFR = "false";
    GITHUB_COPILOT_DISABLED = "1";
    TABNINE_DISABLE_TELEMETRY = "1";
    CODEIUM_DISABLE_TELEMETRY = "1";
    CURSOR_DISABLE_AI = "1";
    VSCODE_DISABLE_WORKSPACE_TRUST = "1";
    JETBRAINS_AI_DISABLED = "1";
    DISABLE_OPENCOLLECTIVE = "1";
  };
}
