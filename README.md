# Tooling around the Eclipse IDE

This repository contains general tooling around the Eclipse IDE such as scripts for building a
specific environment or plug-ins bringing quality of life features or patches.

## Projects

This paragraph provides a quick abstract of all the projects inside this repository as content such
as scripts or plug-ins are grouped together or located in their destinct folder.

#### iBuilds IDE

This creates a destinct Eclipse IDE installation based on the latest (stable) integration build of
the Eclipse SDK with all the necessary features / plug-ins / configurations used for development in
order to dogfood all the components while having a somewhat stable environment for actual proper
development and not just for messing around.

Currently the installed plug-ins are:
- Eclipse Maven integration (m2e)
- SonarLint, optional but enabled by default
- RedDeer UI testing framework
- WindowBuilder

TODOs:
- add configuration application / plug-in for setting up workspace with specific preferences
- back-up workspace in case something breaks
- forbid users to create projects inside the workspace, just outside of it
- install Bndtools snapshot plug-ins

#### Workspace configuration

This is an application / plug-in that is used to configure a workspace based on Eclipse preferences
on the workspace or instance level.

## Knowledge base

This paragraph contains some information for working with the Eclipse IDE in order to access some
information not well known or not publically available.

#### List all available Eclipse Update Sites (after opened at least once) on macOS

> cat $APPLICATION/Contents/Eclipse/p2/org.eclipse.equinox.p2.engine/profileRegistry/$PROFILE/.data/.settings/org.eclipse.equinox.p2.artifact.repository.prefs

The actual URIs are available when running the command piped with `grep "/uri="`.
