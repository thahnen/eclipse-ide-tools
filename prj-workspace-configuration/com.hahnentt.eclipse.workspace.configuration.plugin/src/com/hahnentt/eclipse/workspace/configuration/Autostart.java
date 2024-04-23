package com.hahnentt.eclipse.workspace.configuration;

import org.eclipse.ui.IStartup;

public class Autostart implements IStartup {
	@Override
	public void earlyStartup() {
		// Exists only for the actual plug-in to load automatically instead lazily
	}
}
