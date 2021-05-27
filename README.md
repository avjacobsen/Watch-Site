# Watch-Site
Restarts IIS websites in the csv config file, if they return anything other than StatusCode 200.

It will create a config csv file the first time it's run. Edit that file and then you can make an elevated scheduled task to run every so often by running powershell.exe -file Watch-Site.ps1.

CSV Settings:
- SiteName: The name of the IIS site
- SiteId: The Id of the IIS site
- URL: This is the URL that will be checked
- CheckURI: Whether or not to check the site
- RestartSite: Wether or not to restart the IIS site if the return code is anything but 200.

Todo:
- Make an installer switch that creates scheduled task.
- Make an indexing switch that dumps all sites into csv with CheckURI and RestartSite set to 0.
- Make a switch to assign csv name.
- Make a csv column to assign status code to pass for successful. Currently StatusCode 200 is assumed to be successful.

