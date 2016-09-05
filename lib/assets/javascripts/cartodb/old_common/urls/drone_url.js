/**
 * URL for a map (derived vis).
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
