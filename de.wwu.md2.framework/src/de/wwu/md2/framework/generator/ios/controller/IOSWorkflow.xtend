package de.wwu.md2.framework.generator.ios.controller

import de.wwu.md2.framework.mD2.WorkflowElement
import de.wwu.md2.framework.mD2.WorkflowElementEntry
import org.eclipse.emf.common.util.EList

class IOSWorkflow {
	
	def static String generateWorkflowElements(Iterable<WorkflowElement> elements) '''
«FOR wfe : elements»
    
    let wfe«wfe.name.toFirstUpper» = MD2WorkflowElement(name: "«wfe.name.toFirstUpper»", onInit: MD2CustomAction___«wfe.name.toFirstUpper»_startupAction())
«ENDFOR»
	'''
	
	def static String generateWorkflowEventRegistration(EList<WorkflowElementEntry> elements) '''
«FOR fireEventEntry : elements.map[wfeEntry | wfeEntry.firedEvents.toList ].flatten»
        
    MD2WorkflowEventHandler.instance.registerWorkflowElement(
        MD2WorkflowEvent.«fireEventEntry.event.name.toFirstUpper»,
        «IF fireEventEntry.endWorkflow»
        actionType: MD2WorkflowActionType.End,
        workflowElement: wfe«(fireEventEntry.eContainer as WorkflowElementEntry).workflowElement.name.toFirstUpper»)
        «ELSE»
        actionType: MD2WorkflowActionType.Start,
        workflowElement: wfe«fireEventEntry.startedWorkflowElement.name.toFirstUpper»)
        «ENDIF»
«ENDFOR»
	'''
	
}