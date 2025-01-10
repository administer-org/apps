// pyxfluff 2025

import { execSync } from "child_process";
import { relative, resolve, sep } from "path";

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

console.log(getModifications("src/apps"));