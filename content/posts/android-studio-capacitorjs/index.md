---
title: "Android Studio Capacitorjs - android studio cannot resolve symbol com.capacitor"
date: 2021-12-12T18:52:25-05:00
tags : [ ]
categories : [ android ]
draft: false
---

I've been working with Ionic's Capacitor js as a replacement for Cordova. One thing I just stumbled over is trying to setup a development enviornment for a plugin.

I was getting errors from android studio similar to:
`android studio cannot resolve symbol com.getcapacitor.Plugin`
and when running `./gradlew build`

```
FAILURE: Build failed with an exception.

* What went wrong:
Could not determine the dependencies of task ':verifyReleaseResources'.
> Could not resolve all task dependencies for configuration ':releaseRuntimeClasspath'.
   > Could not resolve project :capacitor-android.
     Required by:
         project :
      > No matching configuration of project :capacitor-android was found. The consumer was configured to find a runtime of a component, as well as attribute 'com.android.build.api.attributes.BuildTypeAttr' with value 'release' but:
          - None of the consumable configurations have attributes.
```

The trick was to run `npm install` in the plugin directory