PoliceJobs = PoliceJobs or {}

PoliceJobs.names = { 'police', 'politi', 'lspd', 'sheriff' }
PoliceJobs.canonical = 'police'
PoliceJobs.lookup = { police = true, politi = true, lspd = true, sheriff = true }

function IsPoliceJob(jobName)
    return jobName ~= nil and PoliceJobs.lookup[jobName] == true
end
