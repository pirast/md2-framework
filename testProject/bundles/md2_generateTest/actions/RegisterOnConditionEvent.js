define([
	"dojo/_base/declare",
	"../../md2_runtime/actions/_Action"
],
function(declare, _Action) {
	
	return declare([_Action], {
		
		_actionSignature: "registerOnConditionEvent",
		
		execute: function() {
			
			var targetContentProvider02i = this.$.contentProviderRegistry.getContentProvider("__conditionalEventMappingsProvider");
			var set02j = this.$.create("boolean", true);
			targetContentProvider02i.setValue("__simple__DisplayMessageAction_d21199be1a3d6d37dc59562c85de9a22__evt", set02j);
			
		}
		
	});
});
