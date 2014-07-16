define([
    "dojo/_base/declare", "dojo/date/stamp", "./_NumericalType"
], function(declare, stamp, _NumericalType) {
    
    return declare([_NumericalType], {
        
        _datatype: "time",
        
        toString: function() {
            return stamp.toISOString(this._platformValue, { selector: "time" });
        },
        
        isSet: function() {
            return this._platformValue;
        },
        
        _equals: function(value) {
            return this._platformValue.getTime() === value.getPlatformValue().getTime();
        },
        
        _gt: function(value) {
            return this._platformValue.getTime() > value.getPlatformValue().getTime();
        },
        
        _gte: function(value) {
            return this._platformValue.getTime() >= value.getPlatformValue().getTime();
        },
        
        _lt: function(value) {
            return this._platformValue.getTime() < value.getPlatformValue().getTime();
        },
        
        _lte: function(value) {
            return this._platformValue.getTime() <= value.getPlatformValue().getTime();
        },
        
        _castFromString: function(value) {
            return stamp.fromISOString(value);
        },
        
        _castFromNumber: function(value) {
            return new Date(value);
        }
        
    });
    
});
