// pyxfluff 2025

import { execSync } from "child_process";
import { existsSync, lstatSync } from "fs";
import { resolve } from "path";

function getModifications(
    basePath: string
): string[] {
    try {
        const modifiedFolders = new Set<string>();

        execSync("git diff --name-only HEAD~1 HEAD", { encoding: "utf-8" }).split("\n").filter(Boolean).forEach((file) => {
            if (resolve(file).startsWith(resolve(basePath))) {
                const folderPath = resolve(file).split("/").slice(0, -1).join("/");

                if (!modifiedFolders.has(folderPath) && existsSync(folderPath) && lstatSync(folderPath).isDirectory()) {
                    modifiedFolders.add(folderPath);
                }
            }
        });

        return Array.from(modifiedFolders);
    } catch (error) {
        console.error("Failed:", error);
        process.exit(1);
    }
}

console.log(getModifications("../apps"));