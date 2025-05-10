# USING

Library of common libraries found in Itos repositories

Add commons to your repo with `git submodules add git@github.com:itos-finance/Commons.git` in your lib folder.

Add `Commons/=lib/Commons/lib/` to your `remappings.txt`

or if you'd like

```
Util/=lib/Commons/lib/Util
Math/=lib/Commons/lib/Math
Commons/=lib/Commons/src
Diamond/=lib/Commons/lib/Diamond
```

# CI

If your repo has a CI that clones the Commons repo, and the Commons repo is still private, the clone will most likely
fail because it doesn't have permission.

This is a pain in the butt, but you need to create a deploy key, add that public key to the deploy keys in Commons and
add the private key to your repo's secrets. Follow the instructions here: https://github.com/webfactory/ssh-agent

We may want to look into access tokens if this becomes a problem, but hopefully our repos go public soon.
