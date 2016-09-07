/**
 * URL for a drone (a type of device).
 */
cdb.common.DroneUrl = cdb.common.Url.extend({

  edit: function() {
    return this.urlToPath('drone');
  },

  public: function() {
    return this.urlToPath('public_drone');
  },

  deepInsights: function() {
    return this.urlToPath('deep-insights');
  }
});
