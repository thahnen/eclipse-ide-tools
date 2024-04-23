package com.hahnentt.eclipse.workspace.configuration;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileWriter;
import java.io.IOException;
import java.io.PrintWriter;
import java.nio.file.FileVisitOption;
import java.nio.file.Files;
import java.time.LocalTime;

import org.eclipse.core.resources.IProject;
import org.eclipse.core.resources.IResource;
import org.eclipse.core.resources.IResourceChangeListener;
import org.eclipse.core.resources.IResourceDelta;
import org.eclipse.core.resources.ResourcesPlugin;
import org.eclipse.core.runtime.CoreException;
import org.eclipse.core.runtime.Platform;
import org.eclipse.ui.plugin.AbstractUIPlugin;
import org.osgi.framework.BundleContext;

/**
 * The activator class controls the plug-in life cycle
 */
public class WorkspaceConfigurationPlugin extends AbstractUIPlugin {
	public static final String PLUGIN_ID = "com.hahnentt.eclipse.workspace.configuration.plugin"; //$NON-NLS-1$
	private static WorkspaceConfigurationPlugin plugin;
	
	private final File logFile = new File(ResourcesPlugin.getWorkspace().getRoot().getLocation().toFile(),
			".metadata/WorkspaceConfiguration.IStartup.log");
	private PrintWriter logWriter;
	private boolean logFileAvailable = true;
	
	private IResourceChangeListener projectListener;
	
	public WorkspaceConfigurationPlugin() {
		// plug-in activator
	}
	
	public static WorkspaceConfigurationPlugin getDefault() {
		return plugin;
	}

	@Override
	public void start(BundleContext context) throws Exception {
		super.start(context);
		plugin = this;
		
		setupLog();
		
		createProjectListener();
		ResourcesPlugin.getWorkspace().addResourceChangeListener(projectListener);
		
		logWriter.close();
	}

	@Override
	public void stop(BundleContext context) throws Exception {
		ResourcesPlugin.getWorkspace().removeResourceChangeListener(projectListener);
		
		plugin = null;
		super.stop(context);
	}
	
	private void createProjectListener() {
		projectListener = event -> {
			if (event.getDelta() == null) {
				return;
			}
			
			try {
				event.getDelta().accept((var delta) -> {
					// We only check for changes on the workspace level!
					if ((delta.getResource().getType() & IResource.ROOT) != 0) {
						IResourceDelta[] children;
						
						// We check for added and changed (e.g. closed -> opened / opened -> closed) transitions
						if (delta.getKind() == IResourceDelta.CHANGED) {
							children = delta.getAffectedChildren(IResourceDelta.CHANGED);
						} else if (delta.getKind() == IResourceDelta.ADDED) {
							children = delta.getAffectedChildren(IResourceDelta.ADDED);
						} else {
							return false;
						}
						
						for (var child: children) {
							var resource = child.getResource();
							
							// We check that only for projects and that they're opened after the transition
							if (((resource.getType() & IResource.PROJECT) != 0)
									&& resource.getProject().isOpen()
									&& ((child.getFlags() & IResourceDelta.OPEN) != 0)) {
								// search project for preference files
								var preferences = searchForPreferenceFiles(resource.getProject());
								for (int i = 0; i < preferences.length; i++) {
									importPreference(preferences[i]);
								}
							}
						}
					}
					
					return false;
				});
			} catch (CoreException err) {
				log("Checking all the event deltas failed", err);
			}
		};
	}
	
	/** We are only interested in preference files ending with ".epf" inside the ".settings" folder */
	private String[] searchForPreferenceFiles(IProject project) {
		project.getFullPath().toPath();
		
		var settingsPath = project.getFullPath().toPath().resolve(".settings");
		String[] actualPreferences = null;
		try (var preferencesFound = Files.find(settingsPath,
					Integer.MAX_VALUE,
					(path, attr) -> path.getFileName().toString().matches(".*\\.epf") && !attr.isDirectory(),
					FileVisitOption.FOLLOW_LINKS)) {
			actualPreferences = (String[]) preferencesFound.map(path -> path.toAbsolutePath().toString()).toArray();
		} catch (IOException err) {
			log("Searching for preference files failed at: " + project, err);
		}
		
		return actualPreferences;
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
