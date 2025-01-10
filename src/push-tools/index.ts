// pyxfluff 2025

import { execSync } from "child_process";
import { resolve, sep } from "path";

function getModifications(basePath: string): string[] {
    try {
        const modifiedFolders = new Set<string>();

        execSync("git diff --name-only HEAD~1 HEAD", { encoding: "utf-8" })
            .split("\n")
            .filter(Boolean)
            .forEach((file) => {
                if (resolve(file).startsWith(resolve(basePath))) {
                    modifiedFolders.add(resolve(basePath, resolve(file).replace(resolve(basePath) + sep, "").split(sep)[0]));
                }
            });

        return Array.from(modifiedFolders);
    } catch (error) {
        console.error("Failed:", error);
        process.exit(1);
    }
}


console.log(getModifications("src/apps"));