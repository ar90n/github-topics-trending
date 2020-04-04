import { Elm } from './Elm/Main.elm';
import { version } from '../package.json';

global.XMLHttpRequest = require('xhr2');

const program = Elm.Main.init({
  flags: {
    argv: process.argv,
    githubToken: process.env.GITHUB_TOKEN || "",
    versionMessage: version
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
