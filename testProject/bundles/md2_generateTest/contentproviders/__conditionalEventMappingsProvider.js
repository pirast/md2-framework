define([
	"dojo/_base/declare",
	"../../md2_runtime/contentprovider/ContentProvider"
],
function(declare, ContentProvider) {
	
	/**
	 * ContentProvider Factory
	 */
	return declare([], {
		
		create: function(typeFactory, $) {
			
			if (!this._localFactory) {
				throw new Error("[__conditionalEventMappingsProvider] No store factory of type 'local' found! "
						+ "Check whether bundle is missing.");
			}
			
			var entityFactory = typeFactory.getEntityFactory("__ConditionalEventMappings");
			var store = this._localFactory.create(entityFactory);
			var appId = "md2_generateTest";
			
			
			return new ContentProvider("__conditionalEventMappingsProvider", appId, store, false);
		}
		
	});
});
