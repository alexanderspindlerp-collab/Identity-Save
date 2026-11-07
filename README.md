# Identity ESX Legacy template

This repository contains the txAdmin recipe and files for the Identity ESX Legacy server.

## Install with txAdmin

1. Make sure this repository is public so txAdmin can download it.
2. In txAdmin, choose **Popular Recipes** or **Remote URL Template** and use:
   `https://raw.githubusercontent.com/alexanderspindlerp-collab/Identity-Save/main/recipe.yaml`
3. Connect a brand-new, empty database when txAdmin asks for database details.
4. Let the recipe finish before starting the server.

The recipe imports the ESX Legacy SQL schema. Do not run the recipe against a database that already has ESX tables. If an earlier setup failed with a message such as `Table 'addon_account' already exists`, that attempt may have created some tables before stopping. Create a new, empty database in your hosting panel and use that database for the next attempt. Do not delete tables from a database that contains data you need.

## Repository files

The recipe downloads the server resources from this repository and the pinned upstream releases listed in `recipe.yaml`. Keep the repository structure intact when updating it; do not upload the ZIP files themselves. txAdmin downloads the extracted repository files, so resource folders must remain in their existing paths.

Custom SQL is listed in `SQL-IMPORT-NOTES.txt` and is not auto-imported. Import only the SQL for resources you enable, after reading each resource's README. Do not rerun the ESX `legacy.sql` dump against an already initialized database.

Only publish scripts you have permission to share. `web_admin_bridge`, `uz_AutoShot`, `r-coords` and `ya_test_npc` are not started by default.
