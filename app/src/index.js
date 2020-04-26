import { Elm } from './Elm/Main.elm';

const APP_ROOT_URL = process.env.APP_ROOT_URL || location.href

const app = Elm.Main.init({
  node: document.getElementById('root'),
  flags: {
    appRootUrl: APP_ROOT_URL
  }
});
