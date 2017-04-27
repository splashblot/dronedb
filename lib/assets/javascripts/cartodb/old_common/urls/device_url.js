/**
 * URL for a device (drone, camera, etc.)
 */
cdb.common.DeviceUrl = cdb.common.Url.extend({

  edit: function() {
    return this.urlToPath('device');
  },

  public: function() {
    return this.urlToPath('public_device');
  },

  deepInsights: function() {
    return this.urlToPath('deep-insights');
  }
});
