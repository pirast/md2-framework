package de.wwu.md2.framework.generator.preprocessor

import de.wwu.md2.framework.generator.preprocessor.util.AbstractPreprocessor
import de.wwu.md2.framework.generator.preprocessor.util.MD2ComplexElementFactory
import de.wwu.md2.framework.mD2.AutoGeneratedContentElement
import de.wwu.md2.framework.mD2.ContainerElementReference
import de.wwu.md2.framework.mD2.WorkflowElement
import java.util.Collection
import org.eclipse.emf.ecore.EObject
import org.eclipse.emf.ecore.resource.ResourceSet

import static extension org.eclipse.emf.ecore.util.EcoreUtil.*

/**
 * Do a Model-to-Model transformation before the actual code generation process
 * to simplify the model.
 */
class MD2Preprocessor extends AbstractPreprocessor {
	
	/**
	 * Each unique input model is only generated once and stored in this class attribute.
	 */
	private static ResourceSet preprocessedModel
	
	/**
	 * A reference to the previous (unpreprocessed) resource set is stored to compare it with
	 * the current one. If they equal, the preprocessing can be skipped and the stored preprocessedModel
	 * is returned.
	 */
	private static ResourceSet previousInputSet
	
	/**
	 * Singleton instance of this preprocessor.
	 */
	private static MD2Preprocessor instance
	
	/**
	 * For each different model resource input, generate the preprocessed model.
	 * The preprocessed ResourceSet is stored in a class attribute, so that for each unique
	 * input model the preprocessor is only run once. Normally, for all generators the input
	 * model is the same so that this factory should be considerably faster.
	 * 
	 * @param input - Original (unprocessed) model.
	 * @return ResourceSet with the preprocessed models.
	 */
	def static getPreprocessedModel(ResourceSet input) {
		if (!input.equals(previousInputSet)) {
			if (instance == null) {
				initialize(new MD2ComplexElementFactory)
				instance = new MD2Preprocessor
			}
			previousInputSet = input
			instance.setNewModel(input)
			preprocessedModel = instance.preprocessModel
		}
		return preprocessedModel
	}
	
	/**
	 * Actual preprocessing processChain.
	 */
	private def preprocessModel() {
		
		/////////////////////////////////////////////////////////////////////////////
		//                                                                         //
		// Collections that are shared between tasks throughout the model          //
		// pre-processing processChain                                             //
		//                                                                         //
		/////////////////////////////////////////////////////////////////////////////
		
		
		// Mapping of cloned (key) and original (value) elements
		// This is necessary to recalculate dependencies such as mappings,
		// event bindings and validator bindings after the cloning of references
		val clonedElements = newHashMap
		
		// all autogenerator elements
		val autoGenerators = view.eAllContents.toIterable.filter(AutoGeneratedContentElement)
		
		// All references to container elements. After cloning the actual containers,
		// the references will be removed in a last step.
		val containerRefs = workingInput.resources.map[ r |
			r.allContents.toIterable.filter(ContainerElementReference)
		].flatten.toList
		
		// All references to view elements that have already been processed. After cloning the
		// actual view elements the references will be removed in a last step.
		val viewRefsDone = newHashSet
		
		// stores the original of all cloned codeFragments mapped to the original of the referenced GUI element
		// ==> that allows to check whether the cloned code fragment references a GUI element that is not child
		//     of any root view. In such cases remove the custom code fragment in another step.
		val clonedCodeFragments = newHashMap
		
		val workflowElements = workingInput.resources.map[ r |
			r.allContents.toIterable.filter(WorkflowElement)
		].flatten.toList
		
		/////////////////////////////////////////////////////////////////////////////
		//                                                                         //
		// Preprocessing Workflow                                                  //
		//                                                                         //
		// HINT: The order of the tasks is relevant as tasks might depend on each  //
		//       other                                                             //
		//                                                                         //
		// TODO: Document (maybe enforce) pre-processing task dependencies         //
		//                                                                         //
		/////////////////////////////////////////////////////////////////////////////
		
		// instantiate all preprocessor classes
		val autoGenerator = new ProcessAutoGenerator
		val controller = new ProcessController
		val conditionalEvents = new ProcessCustomEvents
		val model = new ProcessModel
		val view = new ProcessView
		val viewReferences = new ProcessViewReferences
		val processChains = new ProcessProcessChain
				
		// processChain
		
		controller.replaceDefaultProviderTypeWithConcreteDefinition // done
		
		workflowElements.forEach[wfe | 
			
			controller.createStartUpActionAndRegisterAsOnInitializedEvent(wfe) // done

			controller.setInitialProcessChainAction(wfe) // done
		
			controller.transformEventBindingAndUnbindingTasksToOneToOneRelations(wfe) // done
		
			controller.calculateParameterSignatureForAllSimpleActions(wfe) // done
		]
		
		
		processChains.transformProcessChainsToSequenceOfCoreLanguageElements() // done
		
		workflowElements.forEach[wfe |
			conditionalEvents.transformAllCustomEventsToBasicLanguageStructures(wfe) // done
		]
		
		model.transformImplicitEnums // done
		
		view.setFlowLayoutPaneDefaultParameters // done
		
		view.duplicateSpacers // done
		
		view.replaceNamedColorsWithHexColors // done
		
		workflowElements.forEach[wfe | 
			
			controller.replaceCombinedActionWithCustomAction(wfe) // done
		
			autoGenerator.createAutoGenerationAction(autoGenerators, wfe)  // done
			
			autoGenerator.createViewElementsForAutoGeneratorAction(autoGenerators, wfe) // done
		]
				
		viewReferences.cloneContainerElementReferencesIntoParentContainer(clonedElements, containerRefs) // done
		
		viewReferences.cloneViewElementReferencesIntoParentContainer(clonedElements, viewRefsDone) // done 
		
		viewReferences.replaceStyleReferences // done
				
        workflowElements.forEach[wfe |
        	
            viewReferences.simplifyReferencesToAbstractViewGUIElements(wfe, clonedElements, autoGenerator.autoGenerationActionName) // done
		
			model.createValidatorsForModelConstraints(autoGenerator.autoGenerationActionName, wfe) // done
			
			viewReferences.copyAllCustomCodeFragmentsToClonedGUIElements(clonedElements, clonedCodeFragments, wfe) // done
		
		]
		
        viewReferences.removeAllCustomCodeFragmentsThatReferenceUnusedGUIElements(clonedCodeFragments) // done
		
		view.transformInputsWithLabelsAndTooltipsToLayouts // done
		
		workflowElements.forEach[wfe |
			view.createDisableActionsForAllDisabledViewElements(wfe) // done (with TODO)
		] 
		
		// Remove redundant elements
		val Collection<EObject> objectsToRemove = newHashSet
		objectsToRemove.addAll(autoGenerators)
		objectsToRemove.addAll(containerRefs)
		objectsToRemove.addAll(viewRefsDone)
		for (objRemove : objectsToRemove) {
			objRemove.remove
		}
		
		// after clean-up calculate all grid and element sizes and fill empty cells with spacers,
		// so that calculations are avoided during the actual generation process
		view.transformFlowLayoutsToGridLayouts // done 
		
		view.calculateNumRowsAndNumColumnsParameters // done
		
		view.fillUpGridLayoutsWithSpacers // done
		
		view.calculateAllViewElementWidths // done
		
		
		// Return new ResourceSet
		workingInput.resolveAll
		workingInput
	}
	
}
