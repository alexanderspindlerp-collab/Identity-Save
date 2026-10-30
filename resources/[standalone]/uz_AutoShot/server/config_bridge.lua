-- Bridges Customize fields the server.js needs at event time.
-- JS reads via GetConvar('uz_autoshot_<key>', '<default>').
SetConvar('uz_autoshot_ace_restricted', Customize.AceRestricted and 'true' or 'false')
SetConvar('uz_autoshot_command',        Customize.Command or 'shotmaker')
