# Eclipse workspace configuration (application)

To use this a application, copy the JAR archive into the *dropins* folder of the Eclipse
installation and run the executable from the command line:

```shell
eclipse -nosplash \
    -application WorkspaceConfiguration.Application \
    -data <path to workspace> \
    -projectProjects <path to project or list of projects> \
    -importPreferences <path to preference file or list of preference files> \
    && eclipse -data <path to workspace>
```

In contrast to the application this should be used to create a pre-configured workspace while the
plug-in should be used when there already exists a workspace.
