function triggerUpdate() {
    var ui = SpreadsheetApp.getUi();

    // confirm with user
    var result = ui.alert(
        'Update Addon?',
        'Are you sure you want to trigger a GitHub update and release?',
        ui.ButtonSet.YES_NO);

    if (result == ui.Button.YES) {
        try {
            callGithubAction();
            ui.alert('Success', 'Update triggered! Check GitHub Actions tab for progress.', ui.ButtonSet.OK);
        } catch (e) {
            ui.alert('Error', 'Failed to trigger update: ' + e.message, ui.ButtonSet.OK);
        }
    }
}

function callGithubAction() {
    // CONFIGURATION
    // REPLACE THESE VALUES
    var repoOwner = "Nalhan";
    var repoName = "BotaTools";
    var eventType = "update-lines";

    // Get PAT from Script Properties (File > Project Properties > Script Properties)
    // Property name should be 'GH_PAT'
    var scriptProperties = PropertiesService.getScriptProperties();
    var pat = scriptProperties.getProperty('GH_PAT');

    if (!pat) {
        throw new Error("GitHub Configuration missing. Please set 'GH_PAT' in Script Properties.");
    }

    var url = "https://api.github.com/repos/" + repoOwner + "/" + repoName + "/dispatches";

    var payload = {
        "event_type": eventType
    };

    var options = {
        "method": "post",
        "headers": {
            "Authorization": "Bearer " + pat,
            "Accept": "application/vnd.github.v3+json",
            "Content-Type": "application/json"
        },
        "payload": JSON.stringify(payload)
    };

    var response = UrlFetchApp.fetch(url, options);

    if (response.getResponseCode() !== 204) {
        throw new Error("GitHub API returned: " + response.getResponseCode() + " " + response.getContentText());
    }
}
