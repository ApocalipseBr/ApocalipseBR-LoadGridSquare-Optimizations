const path = require("node:path");
const pzstudio = require("pzstudio/dist/lib/helper.js");

const [project, output] = process.argv.slice(2);
if (!project || !output || !path.isAbsolute(project) || !path.isAbsolute(output)) {
    throw new Error("Expected absolute paths to the staged project and output directory.");
}

// PZ Studio 2.2.0 normally reads the user-wide .pzstudio setting.
// Override it for this packaging process only.
process.chdir(project);
pzstudio.getOutDir = () => output;
require("pzstudio/dist/lib/commands/build.js").buildCmd().catch((error) => {
    console.error(error);
    process.exitCode = 1;
});
