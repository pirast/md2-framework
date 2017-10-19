package de.wwu.md2.framework.generator.preprocessor

import de.wwu.md2.framework.generator.preprocessor.util.AbstractPreprocessor
import de.wwu.md2.framework.mD2.AbstractViewGUIElementRef
import de.wwu.md2.framework.mD2.AlternativesPane
import de.wwu.md2.framework.mD2.AutoGeneratedContentElement
import de.wwu.md2.framework.mD2.ContainerElement
import de.wwu.md2.framework.mD2.ContainerElementReference
import de.wwu.md2.framework.mD2.ContainsCodeFragments
import de.wwu.md2.framework.mD2.ContentProviderPath
import de.wwu.md2.framework.mD2.CustomAction
import de.wwu.md2.framework.mD2.CustomCodeFragment
import de.wwu.md2.framework.mD2.EventBindingTask
import de.wwu.md2.framework.mD2.EventUnbindTask
import de.wwu.md2.framework.mD2.FlowLayoutPane
import de.wwu.md2.framework.mD2.GotoViewAction
import de.wwu.md2.framework.mD2.GridLayoutPane
import de.wwu.md2.framework.mD2.MappingTask
import de.wwu.md2.framework.mD2.SimpleType
import de.wwu.md2.framework.mD2.StyleReference
import de.wwu.md2.framework.mD2.TabSpecificParam
import de.wwu.md2.framework.mD2.UnmappingTask
import de.wwu.md2.framework.mD2.ValidatorBindingTask
import de.wwu.md2.framework.mD2.ValidatorUnbindTask
import de.wwu.md2.framework.mD2.View
import de.wwu.md2.framework.mD2.ViewElement
import de.wwu.md2.framework.mD2.ViewElementEventRef
import de.wwu.md2.framework.mD2.ViewElementType
import de.wwu.md2.framework.mD2.ViewGUIElement
import de.wwu.md2.framework.mD2.ViewGUIElementReference
import de.wwu.md2.framework.mD2.WorkflowElement
import java.util.Collection
import java.util.HashMap
import org.eclipse.emf.common.util.EList
import org.eclipse.emf.ecore.EObject
import org.eclipse.xtext.naming.DefaultDeclarativeQualifiedNameProvider

import static de.wwu.md2.framework.generator.preprocessor.util.Helper.*
import static de.wwu.md2.framework.generator.preprocessor.util.Util.*

import static extension de.wwu.md2.framework.generator.util.MD2GeneratorUtil.*
import static extension org.eclipse.emf.ecore.util.EcoreUtil.*
import de.wwu.md2.framework.generator.util.MD2GeneratorUtil

class ProcessViewReferences extends AbstractPreprocessor {
	
	/**
	 * Clone nested ContainerElement references into parent container.
	 */
	def cloneContainerElementReferencesIntoParentContainer(
		HashMap<ViewElementType, ViewElementType> clonedElements, Iterable<ContainerElementReference> containerRefs
	) {
		containerRefs.forEach [ containerRef |
			val containerElement = copyViewElementType(containerRef.value, clonedElements)
			if (containerRef.rename) containerElement.name = containerRef.name
			containerRef.params.forEach [ param |
				val newParam = copyElement(param as TabSpecificParam)
				switch (containerElement) {
					GridLayoutPane: containerElement.params.add(newParam)
					FlowLayoutPane: containerElement.params.add(newParam)
					AlternativesPane: containerElement.params.add(newParam)
				}
			]
			val EList<EObject> elements = containerRef.eContainer.eGet(containerRef.eContainingFeature) as EList<EObject>
			elements.add(elements.indexOf(containerRef), containerElement)
		]
	}
	
	/**
	 * Clone nested ViewElement references into parent container.
	 */
	def cloneViewElementReferencesIntoParentContainer(
		HashMap<ViewElementType, ViewElementType> clonedElements, Collection<ViewGUIElementReference> viewRefsDone
	) {
		var repeat = true
		while (repeat) {
			val viewRefs = view.eAllContents.toIterable.filter(ViewGUIElementReference).toList.sortWith([obj1, obj2 |
				return countContainers(obj2, 0) - countContainers(obj1, 0)
			])
			val size = viewRefsDone.size 
			viewRefs.forEach [ viewRef |
				if (!viewRefsDone.contains(viewRef)) {
					val viewElement = copyViewElementType(viewRef.value, clonedElements)
					if (viewRef.rename) viewElement.name = viewRef.name
					val elements = viewRef.eContainer.eGet(viewRef.eContainingFeature) as EList<EObject>
					elements.add(elements.indexOf(viewRef), viewElement)
					viewRefsDone.add(viewRef)
				}
			]
			// For the lack of mutable Booleans
			repeat = (viewRefsDone.size != size)
		}
	}
	
	/**
	 * Replace style reference with referenced style definition.
	 */
	def replaceStyleReferences() {
	    val styleRefs = view.eAllContents.toIterable.filter(StyleReference).toList
		
		styleRefs.forEach[ styleRef |
			val styleDef = factory.createStyleDefinition()
			styleDef.definition = copyElement(styleRef.reference.body)
			styleRef.replace(styleDef)
		]
	}
	
	/**
	 * Copy all CustomCodeFragments from regular (non-startup) actions from original to cloned/auto-generated GUI elements.
	 * 
	 * <p>
	 *   DEPENDENCIES:
	 * </p>
	 * <ul>
	 *   <li>
	 *     <i>cloneViewElementReferencesIntoParentContainer</i> - All elements have to be cloned and the <i>clonedElements</i> hash
	 *     map has to be populated before the references can be cloned.
	 *   </li>
	 * </ul>
	 */
	def copyAllCustomCodeFragmentsToClonedGUIElements(
		HashMap<ViewElementType, ViewElementType> clonedElements, 
		HashMap<CustomCodeFragment, ViewElementType> clonedCodeFragments,
		WorkflowElement wfe) {
		
		val codeFragments = wfe.eAllContents.toIterable.filter(CustomCodeFragment).toList
		// get a list of all ViewElements that are referenced in the WorkflowElement
		val viewElementsReferencedInWorkflow = wfe.eAllContents.filter(AbstractViewGUIElementRef).map[it.ref as ViewElement]
		// get all view elements that belong to views referenced by the WorkflowElement
		val workflowSpecificViewElements = viewElementsReferencedInWorkflow.map[it.eAllContents.toList].toList.flatten.toList
		
		for (codeFragment : codeFragments) {
			// TODO: multiple switch-cases eventually reduce from three to six,
			// because they are similar (e.g., what is done in EventBindingTask is similar to EventUnbindingTask)
			switch (codeFragment) {
				EventBindingTask: {
					codeFragment.events.filter(typeof(ViewElementEventRef)).forEach [ eventRef |
						clonedElements.forEach[ cloned, original |
							if (original == eventRef.referencedField.resolveViewElement) {
								val newTask = copyElement(codeFragment)
								newTask.events.clear
								val newEventRef = factory.createViewElementEventRef()
								val newAbstractRef = factory.createAbstractViewGUIElementRef()
								
								val nestedAbstractViewGUIElementRef = factory.createAbstractViewGUIElementRef
								newAbstractRef.ref = MD2GeneratorUtil.getViewFrameForGUIElement(cloned)
								newAbstractRef.tail = nestedAbstractViewGUIElementRef
								nestedAbstractViewGUIElementRef.viewElementRef = cloned
							
								newEventRef.referencedField = newAbstractRef
								newEventRef.event = eventRef.event
								newTask.events.add(newEventRef)
								newTask.addToParentCodeContainer(codeFragment.eContainer)
								clonedCodeFragments.put(codeFragment, original)
							}
						]
					]
				}
				EventUnbindTask: {
					codeFragment.events.filter(typeof(ViewElementEventRef)).forEach [ eventRef |
						clonedElements.forEach[ cloned, original |
							if (original == eventRef.referencedField.resolveViewElement) {
								val newTask = copyElement(codeFragment)
								newTask.events.clear
								val newEventRef = factory.createViewElementEventRef()
								val newAbstractRef = factory.createAbstractViewGUIElementRef()
								
								val nestedAbstractViewGUIElementRef = factory.createAbstractViewGUIElementRef
								newAbstractRef.ref = MD2GeneratorUtil.getViewFrameForGUIElement(cloned)
								newAbstractRef.tail = nestedAbstractViewGUIElementRef
								nestedAbstractViewGUIElementRef.viewElementRef = cloned
								
								newEventRef.referencedField = newAbstractRef
								newEventRef.event = eventRef.event
								newTask.events.add(newEventRef)
								newTask.addToParentCodeContainer(codeFragment.eContainer)
								clonedCodeFragments.put(codeFragment, original)
							}
						]				
					]
				}
				ValidatorBindingTask: {
					for (abstractRef : codeFragment.referencedFields) {
						clonedElements.forEach[ cloned, original |
							if (original == abstractRef.resolveViewElement) {
								val newTask = copyElement(codeFragment)
								newTask.referencedFields.clear
								val newAbstractRef = factory.createAbstractViewGUIElementRef()
								
								val nestedAbstractViewGUIElementRef = factory.createAbstractViewGUIElementRef
								newAbstractRef.ref = MD2GeneratorUtil.getViewFrameForGUIElement(cloned)
								newAbstractRef.tail = nestedAbstractViewGUIElementRef
								nestedAbstractViewGUIElementRef.viewElementRef = cloned
								
								newAbstractRef.tail = nestedAbstractViewGUIElementRef
								newTask.referencedFields.add(newAbstractRef)
								newTask.addToParentCodeContainer(codeFragment.eContainer)
								clonedCodeFragments.put(codeFragment, original)
							}
						]
					}
				}
				ValidatorUnbindTask: {
					for (abstractRef : codeFragment.referencedFields) {
						clonedElements.forEach[ cloned, original |
							if (original == abstractRef.resolveViewElement) {
								val newTask = copyElement(codeFragment)
								newTask.referencedFields.clear
								val newAbstractRef = factory.createAbstractViewGUIElementRef()
								
								val nestedAbstractViewGUIElementRef = factory.createAbstractViewGUIElementRef
								newAbstractRef.ref = MD2GeneratorUtil.getViewFrameForGUIElement(cloned)
								newAbstractRef.tail = nestedAbstractViewGUIElementRef
								nestedAbstractViewGUIElementRef.viewElementRef = cloned
								
								newTask.referencedFields.add(newAbstractRef)
								newTask.addToParentCodeContainer(codeFragment.eContainer)
								clonedCodeFragments.put(codeFragment, original)
							}
						]
					}
				}
				MappingTask: {
					clonedElements.forEach[ cloned, original |
						if (original == codeFragment.referencedViewField.resolveViewElement && workflowSpecificViewElements.contains(cloned)) {		
							val newTask = copyElement(codeFragment)
							val newAbstractRef = factory.createAbstractViewGUIElementRef()
							
							val nestedAbstractViewGUIElementRef = factory.createAbstractViewGUIElementRef
							newAbstractRef.ref = MD2GeneratorUtil.getViewFrameForGUIElement(cloned)
							newAbstractRef.tail = nestedAbstractViewGUIElementRef
							nestedAbstractViewGUIElementRef.viewElementRef = cloned
							
							newTask.referencedViewField = newAbstractRef
							newTask.addToParentCodeContainer(codeFragment.eContainer)
							clonedCodeFragments.put(codeFragment, original)
						}
					]
				}
				UnmappingTask: {
					clonedElements.forEach[ cloned, original |
						if (original == codeFragment.referencedViewField.resolveViewElement && workflowSpecificViewElements.contains(cloned)) {		
							val newTask = copyElement(codeFragment)
							val newAbstractRef = factory.createAbstractViewGUIElementRef()
							
							val nestedAbstractViewGUIElementRef = factory.createAbstractViewGUIElementRef
							newAbstractRef.ref = MD2GeneratorUtil.getViewFrameForGUIElement(cloned)
							newAbstractRef.tail = nestedAbstractViewGUIElementRef
							nestedAbstractViewGUIElementRef.viewElementRef = cloned
								
							newTask.referencedViewField = newAbstractRef
							newTask.addToParentCodeContainer(codeFragment.eContainer)
							clonedCodeFragments.put(codeFragment, original)
						}
					]
				}
			}
		}
	}
	
	/**
	 * There might exist custom code fragments (BindEventTask, BindValidatorTask, MappingTask...)
	 * that reference a GUI element that is not child of any root view. This step checks whether the cloned code fragment's
	 * referenced GUI element is contained in any root view. If not, the fragment is removed.
	 * 
	 * <p>
	 *   DEPENDENCIES:
	 * </p>
	 * <ul>
	 *   <li>
	 *     <i>copyAllCustomCodeFragmentsToClonedGUIElements</i> - This step clones the respective code fragments and stores the
	 *     originals in a hash map. This hash map is used in this step.
	 *   </li>
	 * </ul>
	 */
	def removeAllCustomCodeFragmentsThatReferenceUnusedGUIElements(HashMap<CustomCodeFragment, ViewElementType> clonedCodeFragments) {
		val gotoViewActions = controller.eAllContents.toIterable.filter(GotoViewAction)
		
		// get all containers that are used as views
		val rootViews = gotoViewActions.map[ action | action.view.resolveViewElement].toSet
		
		// check for all cloned code fragments if they are child of any of the root views
		// => if not remove code fragment
		clonedCodeFragments.forEach[ codeFragment, viewElement |
			var eObject = viewElement.eContainer
			var isLoop = true
			while (isLoop) {
				if (eObject instanceof View) {
					codeFragment.remove
					isLoop = false
				} else if (eObject instanceof ContainerElement && rootViews.contains(eObject)) {
					isLoop = false
				}
				eObject = eObject.eContainer
			}
		]
	}
	
	/**
	 * Simplify references to AbstractViewGUIElements (auto-generated and/or cloned)
	 * Set ViewGUIElement to head ref
	 */
	def simplifyReferencesToAbstractViewGUIElements(WorkflowElement wfe, HashMap<ViewElementType, ViewElementType> clonedElements, String autoGenerationActionName) {
		val abstractRefs = wfe.eAllContents.toIterable.filter(AbstractViewGUIElementRef).filter([!(it.eContainer instanceof AbstractViewGUIElementRef)])
		
		val autogenAction = wfe.eAllContents.filter(CustomAction).filter(action | action.name == autoGenerationActionName).last
		
//		TODO check and fix
//		abstractRefs.forEach[ abstractRef |
//			abstractRef.ref = resolveAbstractViewGUIElementRef(abstractRef, null, clonedElements, autogenAction)
//			abstractRef.tail?.remove
//			abstractRef.path?.remove
//			abstractRef.simpleType?.remove
//		]
	}
	
	/**
	 * Add a CustomCodeFragment to a block of code.
	 * 
	 * Helper method to distinguish on whether a CustomCodeFragment is the direct child of a CustomAction or whether it is part of a
	 * ConditionalCodeFragment (if-else-conditions).
	 */
	private def addToParentCodeContainer(CustomCodeFragment codeFragment, EObject container) {
		if (!(container instanceof ContainsCodeFragments)) {
			throw new Error("Tried to add a code fragment to an element that does not contain code fragments!");
		}
		val codeFragmentContainer = container as ContainsCodeFragments
		codeFragmentContainer.codeFragments.add(codeFragment)
	}
	
	/**
	 * Look up pseudo-referenced ViewGUIElement
	 */
	private def ViewGUIElement resolveAbstractViewGUIElementRef(
		AbstractViewGUIElementRef abstractRef, ViewGUIElement guiElem, HashMap<ViewElementType, ViewElementType> clonedElements,
		CustomAction getAutoGenAction
	) {
		var nextGuiElem = guiElem
		val qualifiedNameProvider = new DefaultDeclarativeQualifiedNameProvider()
		if (abstractRef.ref instanceof ViewGUIElement) {
			if (guiElem == null) {
				nextGuiElem = abstractRef.ref as ViewGUIElement
			} else {
				var qualifiedName = qualifiedNameProvider.getFullyQualifiedName(abstractRef.ref)
				for (searchName : qualifiedName.skipFirst(1).segments) {
					nextGuiElem = nextGuiElem.eAllContents.filter(typeof(ViewGUIElement)).findFirst(searchGuiElem | searchGuiElem.name != null && searchGuiElem.name.equals(searchName))
				}
			}
		} else if (abstractRef.ref instanceof ViewGUIElementReference) {
			if (guiElem == null) {
				nextGuiElem = abstractRef.ref.eContainer as ViewGUIElement
			}
			val searchName = abstractRef.ref.name
			nextGuiElem = nextGuiElem.eAllContents.filter(typeof(ViewGUIElement)).findFirst[
				searchGuiElem | searchGuiElem.name != null && searchGuiElem.name.equals(searchName)
			]
		}
		if (nextGuiElem instanceof AutoGeneratedContentElement) {
			val parentGuiElem = nextGuiElem.eContainer.eContainer
			
			// Use initial mappings
			var Iterable<MappingTask> mappingTasks = getAutoGenAction.codeFragments.filter(typeof(MappingTask))
			if (abstractRef.path != null) {
				// ReferencedModelType
				mappingTasks = mappingTasks.toList.filter([(it.pathDefinition as ContentProviderPath).referencedAttribute == abstractRef.path.referencedAttribute])
			} else {
				// SimpleType
				mappingTasks = mappingTasks.toList.filter([(it.pathDefinition as ContentProviderPath).contentProviderRef.type instanceof SimpleType]).filter([((it.pathDefinition as ContentProviderPath).contentProviderRef.type as SimpleType).type == abstractRef.simpleType.type])
			}
			val Collection<EObject> candidates = newArrayList
			mappingTasks.map([it.referencedViewField.ref]).forEach [ mappedGuiElem |
				candidates.add(mappedGuiElem)
				candidates.addAll(clonedElements.filter([key, value | value.equals(mappedGuiElem)]).keySet)
			]
			nextGuiElem = candidates?.findFirst(candidate | parentGuiElem.isAncestor(candidate)) as ViewGUIElement
		}
		if (abstractRef.getTail != null) {
			return resolveAbstractViewGUIElementRef(abstractRef.getTail(), nextGuiElem, clonedElements, getAutoGenAction) 
		} else {
			return nextGuiElem;
		}
	}
	
}