package com.hahnentt.adtclipse.plugin;

import org.eclipse.ui.application.IWorkbenchConfigurer;
import org.eclipse.ui.internal.ide.application.DelayedEventsProcessor;
import org.eclipse.ui.internal.ide.application.IDEWorkbenchAdvisor;

@SuppressWarnings("restriction")
public class ADTClipseWorkbenchAdvisor extends IDEWorkbenchAdvisor {
	public ADTClipseWorkbenchAdvisor(final DelayedEventsProcessor processor) {
		super(processor);
	}
	
	@Override
	public void initialize(final IWorkbenchConfigurer configurer) {
		super.initialize(configurer);
	}
}
