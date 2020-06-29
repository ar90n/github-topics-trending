# github-topics-trending
Static web site and its crawler for Topics in GitHub Trending. All you need is only GitHub.

[Demo](https://ar90n.github.io/github-topics-trending/)

## Features
* Crawler works in GitHub Action
* Web pages are hosted in GitHub Pages

## Start with development server
```
$ APP_ROOT_URL=https://ar90n.github.io/github-topics-trending/ yarn start
```

## Start crawling manually
Crawling starts at 0300 UTC.
But you can start it manually by the following if you need.
```
$ export GITHUB_TOKEN=<your github access token>
$ ./tool/request.sh
```

## License
This software is released under the Apache License, see [LICENSE](LICENSE).
