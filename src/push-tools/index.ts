// pyxfluff 2025

import { join } from "path";
import { execSync } from "child_process";
import { readFileSync, writeFileSync, unlinkSync } from "fs";
import { relative, resolve, sep } from "path";

import { validateAppServerConfig } from "./modules/validateFile";

type appFolderConfig = {
    uploadToAppServer: Boolean,
    shouldCommitChanges: Boolean
}

function getModifications(
    basePath: string
): string[] {
    try {
        const modifiedFolders = new Set<string>();

        execSync("git diff --name-only HEAD~1 HEAD", { encoding: "utf-8" })
            .split("\n")
            .filter(Boolean)
            .forEach((file) => {
                const absolutePath = resolve(file);
                if (absolutePath.startsWith(resolve(basePath))) {
                    modifiedFolders.add(`${basePath}/${relative(resolve(basePath), absolutePath).split(sep)[0]}`.replace(/\\/g, "/")); // Normalize path
                }
            });

        return Array.from(modifiedFolders);
    } catch (error) {
        console.error("Failed:", error);
        process.exit(1);
    }
}

function enableGitPush(proposedValue: Boolean, config: appFolderConfig) {
    // This function just exists to save lines tbh
    if (config.shouldCommitChanges && !proposedValue) return;

    config.shouldCommitChanges = true;
}

function processModifications(modifiedFolders: string[]) {
    const steps: { [key: string]: (folderPath: string, existingConfig: appFolderConfig) => [boolean, boolean, string | null] } = {
        // @ts-ignore
        "Check app_server_config.json file": (folderPath: string, existingConfig: appFolderConfig) => {
            let file: string;
            try {
                file = readFileSync(join(folderPath, "app_server_config.json"), "utf-8");

                if (file == "") {
                    console.error("This file is blank! It will be deleted.");
                    enableGitPush(true, existingConfig)
                }
            } catch (e) {
                console.log("Failed to read app_server_config.json, assuming it doesn't exist.");
                return [false, false, "AppServerConfig does not exist so we must not be going on the app server."];
            };

            existingConfig.uploadToAppServer = validateAppServerConfig(file);
            enableGitPush(existingConfig.uploadToAppServer, existingConfig)

            if (existingConfig.uploadToAppServer && process.argv.slice(2).includes("--git-enabled")) {
                if (!process.argv.slice(2)[1].startsWith("--ADM-_TOK-_")) {
                    console.error("Authentication token not passed through (or git flag missing); please make sure both are enabled!");
                    return;
                }

                fetch("https://administer.notpyx.me/app-config/upload", {
                    method: "POST",
                    headers: {
                        "X-Adm-Auth": process.argv.slice(2)[1],
                        "X-Adm-Sys-Vers": "1.0",
                        "user-agent": "Administer System (App Validator; TypeScript; GitHub Actions)",
                    },
                    body: file
                });

                unlinkSync(join(folderPath, "app_server_config.json"));
            }

            return [existingConfig.uploadToAppServer, !existingConfig.uploadToAppServer, "Please read the log for more information."];
        }
    };

    console.log("Processing updates...");
    modifiedFolders.forEach((folder) => {
        let config: appFolderConfig = { uploadToAppServer: true, shouldCommitChanges: false }

        console.log("•", folder);

        for (const desc in steps) {
            console.log(`Testing: ${desc}`);
            let result: [boolean, boolean, string | null] = steps[desc](join(process.cwd().replace("/src/push-tools", ""), folder), config);

            if (!result[0] && result[1]) {
                console.error(`Your app server configuration is invalid! ${result[2]}`)
                process.exit(1)
            }
        }
    });
}



const mods = getModifications("src/apps");

console.log(mods);
processModifications(["src/apps/Announcements"])
