package com.hahnentt.adtclipse.plugin;

import java.net.URL;

import org.eclipse.core.runtime.Platform;
import org.eclipse.core.runtime.jobs.Job;
import org.eclipse.core.runtime.preferences.ConfigurationScope;
import org.eclipse.equinox.app.IApplicationContext;
import org.eclipse.jdt.annotation.Nullable;
import org.eclipse.jface.window.Window;
import org.eclipse.swt.widgets.Shell;
import org.eclipse.ui.PlatformUI;
import org.eclipse.ui.internal.Workbench;
import org.eclipse.ui.internal.WorkbenchPlugin;
import org.eclipse.ui.internal.ide.ChooseWorkspaceDialog;
import org.eclipse.ui.internal.ide.IDEInternalPreferences;
import org.eclipse.ui.internal.ide.IDEWorkbenchPlugin;
import org.eclipse.ui.internal.ide.application.DelayedEventsProcessor;
import org.eclipse.ui.internal.ide.application.IDEApplication;
import org.eclipse.ui.preferences.ScopedPreferenceStore;

@SuppressWarnings("restriction")
public class ADTClipseApplication extends IDEApplication {
	@Override
	public Object start(final @Nullable IApplicationContext ctx) throws Exception {
		Job.getJobManager().suspend();
		
		final var display = createDisplay();
		
		try {
			final var processor = new DelayedEventsProcessor(display);
			final var shell = WorkbenchPlugin.getSplashShell(display);
			if (shell != null) {
				shell.setText(ChooseWorkspaceDialog.getWindowTitle());
				shell.setImages(Window.getDefaultImages());
			}
			
			final var instanceLocationCheck = checkInstanceLocation(shell, ctx.getArguments());
			if (instanceLocationCheck != null) {
				WorkbenchPlugin.unsetSplashShell(display);
				return instanceLocationCheck;
			}
			
			final var rc = PlatformUI.createAndRunWorkbench(display, new ADTClipseWorkbenchAdvisor(processor));
			if (rc != PlatformUI.RETURN_RESTART) {
				return EXIT_OK;
			}
			
			return EXIT_RELAUNCH.equals(Integer.getInteger(Workbench.PROP_EXIT_CODE)) ? EXIT_RELAUNCH : EXIT_RESTART;
		} finally {
			display.dispose();
			
			final var instanceLoc = Platform.getInstanceLocation();
			if (instanceLoc != null) {
				instanceLoc.release();
			}
		}
	}
	
	@Nullable
	@Override
	protected ReturnCode checkValidWorkspace(final @Nullable Shell shell, final @Nullable URL url) {
		final var workbenchPrefs = new ScopedPreferenceStore(ConfigurationScope.INSTANCE, IDEWorkbenchPlugin.IDE_WORKBENCH);
		workbenchPrefs.setValue(IDEInternalPreferences.WARN_ABOUT_WORKSPACE_INCOMPATIBILITY, false);
		
		return super.checkValidWorkspace(shell, url);
	}
}
