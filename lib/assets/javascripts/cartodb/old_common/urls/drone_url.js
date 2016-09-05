/**
 * URL for a drone.
 */
cdb.common.DatasetUrl = cdb.common.Url.extend({

  edit: function() {
    return this.urlToPath();
  },

  public: function() {
    return this.urlToPath('public');
  }
});
