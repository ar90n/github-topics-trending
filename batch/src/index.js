import { Elm } from './Elm/Main.elm';

global.XMLHttpRequest = require('xhr2');

const program = Elm.Main.init({
  flags: {
    argv: process.argv,
    githubToken: process.env.GITHUB_TOKEN || "",
    versionMessage: process.env.npm_package_version
  }
});

program.ports.print.subscribe(message => {
  console.log(message)
});

program.ports.printAndExitFailure.subscribe(message => {
  console.log(message);
  process.exit(1);
});

program.ports.printAndExitSuccess.subscribe(message => {
  console.log(message);
  process.exit(0);
});
