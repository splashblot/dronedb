
/**
 * the device has some base layers saved
 */
cdb.admin.DeviceLayers = cdb.admin.Layers.extend({
  url: function(method) {
    var version = cdb.config.urlVersion('layer', method);
    return '/api/' + version + '/devices/' +  this.device.id + '/layers';
  },

  custom: function() {
    return this.where({ category: undefined });
  }
});

cdb.admin.Device = cdb.core.Model.extend({

  urlRoot: '/api/v1/devices',

  defaults: {
    avatar_url: 'http://cartodb.s3.amazonaws.com/static/public_dashboard_default_avatar.png',
    nickname:   ''
  },

  initialize: function(attrs) {
    attrs = attrs || {};
    this.tables = [];
    // Removing avatar_url attribute if it comes as null
    // Due to a Backbone Model constructor uses _.extends
    // instead of _.defaults
    if (this.get("avatar_url") === null) {
      this.set("avatar_url", this.defaults.avatar_url);
    }

    if (this.get("get_layers")) {
      this.layers = new cdb.admin.DeviceLayers();
      this.layers.device = this;
      this._fetchLayers();
    }

    this.email = (typeof attrs.email !== 'undefined') ? attrs.email : '';

    if (this.get('organization')) {
      this.organization = new cdb.admin.Organization(
        this.get('organization'),
        {
          currentDeviceId: this.id
        }
      );
    }

    this.groups = new cdb.admin.DeviceGroups(attrs.groups, {
      organization: _.result(this.collection, 'organization') || this.organization
    });
  },

  isInsideOrg: function() {
    if (this.organization) {
      return this.organization.id != false;
    }
    return false;
  },

  nameOrNickname: function() {
    return this.get('name') || this.get('nickname');
  },

  renderData: function(currentDevice) {
    var name = this.get('nickname');
    return {
      nickname: name,
      avatar_url: this.get('avatar_url')
    }

  },

  fetchTables: function() {
    var self = this;
    if (this._fetchingTables)  return;
    var tables = new cdb.admin.Visualizations();
    tables.options.set('type', 'table')
    tables.bind('reset', function() {
      self.tables = tables.map(function(u) { return u.get('name'); })
    })
    this._fetchingTables = true;
    tables.fetch();
  },

  equals: function(otherDevice) {
    if (otherDevice.get) {
      return this.get('id') === otherDevice.get('id');
    }
  },

  viewUrl: function() {
    return new cdb.common.DeviceUrl({
      base_url: this.get('base_url'),
    });
  }

});
