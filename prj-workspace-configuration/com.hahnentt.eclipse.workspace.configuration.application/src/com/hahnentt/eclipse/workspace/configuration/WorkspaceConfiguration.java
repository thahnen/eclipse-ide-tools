package com.hahnentt.eclipse.workspace.configuration;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileWriter;
import java.io.IOException;
import java.io.PrintWriter;
import java.time.LocalTime;

import org.eclipse.core.resources.IProject;
import org.eclipse.core.resources.ResourcesPlugin;
import org.eclipse.core.runtime.CoreException;
import org.eclipse.core.runtime.Path;
import org.eclipse.core.runtime.Platform;
import org.eclipse.equinox.app.IApplication;
import org.eclipse.equinox.app.IApplicationContext;

public class WorkspaceConfiguration implements IApplication {
	private final File logFile = new File(ResourcesPlugin.getWorkspace().getRoot().getLocation().toFile(),
			".metadata/WorkspaceConfiguration.IApplication.log");
	private PrintWriter logWriter;
	private boolean logFileAvailable = true;

	@Override
	public Object start(IApplicationContext context) throws Exception {
		setupLog();
		
		// handle the application arguments as all "commands" come as pairs
		var args = (String[]) context.getArguments().get(IApplicationContext.APPLICATION_ARGS);
		for (int i = 0; i < args.length; ++i) {
			if ("-projectProjects".equals(args[i]) && i+1 < args.length) {
				importProjects(args[++i]);
			}
			if ("-importPreferences".equals(args[i]) && i+1 < args.length) {
				importPreferences(args[++i]);
			}
		}
		
		// save workspace for the next start of Eclipse
		try {
			ResourcesPlugin.getWorkspace().save(true, null);
			log("The workspace was saved successfully");
		} catch (CoreException err) {
			log("The workspace couldn't be saved", err);
		}
		
		return null;
	}

	@Override
	public void stop() {
		logWriter.close();
	}
	
	private void importProjects(String projects) {
		var actualProjects = projects.split(",");
		for (int i = 0; i < actualProjects.length; i++) {
			importProject(actualProjects[i]);
		}
	}
	
	private void importProject(String project) {
		IProject projectObj;
		
		try {
			var projectFile = ResourcesPlugin.getWorkspace()
					.loadProjectDescription(new Path(project).append(".project"));
			projectObj = ResourcesPlugin.getWorkspace().getRoot().getProject(projectFile.getName());
			try {
				try {
					projectObj.create(projectFile, null);
				} catch (Exception ignored) {
					projectFile.setLocationURI(null);
					projectObj.create(projectFile, null);
				}
			} catch (CoreException err) {
				log("Project already exists in workspace at: " + project, err);
				return;
			}
		} catch (CoreException err) {
			log("Project does not exist at: " + project, err);
			return;
		}
		
		try {
			if (!projectObj.isOpen()) {
				projectObj.open(null);
				log("Project imported and opened at: " + project);
			} else {
				log("Project imported at: " + project);
			}
		} catch (CoreException err) {
			log("Project imported, but could not be opened at: " + project, err);
		}
	}
	
	private void importPreferences(String preferences) {
		var actualPreferences = preferences.split(",");
		for (int i = 0; i < actualPreferences.length; i++) {
			importPreference(actualPreferences[i]);
		}
	}
	
	private void importPreference(String preference) {
		try {
			var importService = Platform.getPreferencesService();
			importService.importPreferences(new FileInputStream(new File(preference)));
			log("Preferences imported at: " + preference);
		} catch (Exception err) {
			log("Preferences could not be imported at: " + preference, err);
		}
	}
	
	private void setupLog() {
		if (!logFile.exists()) {
			try {
				logFile.createNewFile();
			} catch (IOException ignored) {
				logFileAvailable = false;
			}
		}
		
		try {
			logWriter = new PrintWriter(new FileWriter(logFile.getAbsoluteFile(), true));
		} catch (IOException ignored) {
			logFileAvailable = false;
		}
	}
	
	private void log(String message) {
		if (logFileAvailable) {
			logWriter.println("[" + LocalTime.now() + "]         " + message);
			logWriter.flush();
		}
	}
	
	private void log (String message, Throwable t) {
		if (logFileAvailable) {
			logWriter.println("[" + LocalTime.now() + "] [ERROR] " + message);
			if (t != null) {
				t.printStackTrace(logWriter);
			}
			logWriter.flush();
		}
	}
}
