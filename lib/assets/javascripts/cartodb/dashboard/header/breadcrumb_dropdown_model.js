var cdb = require('cartodb.js-v3');

module.exports = cdb.core.Model.extend({

  initialize: function(router) {
    this.router = router;
  },

  breadcrumbTitle: function() {
    var contentType = this.router.model.get('content_type');
    var isLocked = this.router.model.get('locked');

    var title;
    if (contentType === 'datasets') {
      if (isLocked) {
        title = 'Locked datasets';
      } else {
        title = 'Datasets';
      }
    } else if (contentType === 'drones') {
      if (isLocked) {
        title = 'Locked drones';
      } else {
        title = 'Drones';
      }
    } else {
      if (isLocked) {
        title = 'Locked maps';
      } else {
        title = 'Maps';
      }
    }

    return title;
  },

  isOnDatasetsRoute: function() {
    return this.router.model.get('content_type') === 'datasets';
  },

  isOnDevicesRoute: function() {
    return this.router.model.get('content_type') === 'drones';
  },

  isOnMapsRoute: function() {
    return this.router.model.get('content_type') === 'maps';
  },

  isOnLockedRoute: function() {
    return !!this.router.model.get('locked');
  }
});
