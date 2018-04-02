var ImportModel = require('../../data/background-importer/import-model');

module.exports = function (opts) {
  if (!opts.tableModel) throw new Error('tableModel is required');
  if (!opts.query) throw new Error('query is required');
  if (!opts.configModel) throw new Error('configModel is required');

  var tableModel = opts.tableModel;
  var configModel = opts.configModel;
  var query = opts.query;
  var successCallback = opts.onSuccess;
  var errorCallback = opts.onError;
  // PostgreSQL column name's max length is 63. 63 - '_copy'.length = 58
  // 58 - '_raster'.length - overviews = 46
  var name = tableModel.getUnqualifiedName();
  var suffix = '_copy';
  if (name.length > 45) {
    var maxlength = (name.indexOf('_raster') !== -1) ? 46 : 58;
    suffix = (maxlength === 46) ? '_raster_copy' : '_copy';
  }
  var attrs = {
    table_name: name.substring(0, maxlength) + suffix,
    sql: query
  };

  var importModel = new ImportModel({}, {
    configModel: configModel
  });
  importModel.save(attrs, {
    error: errorCallback && errorCallback,
    success: function (model, changes) {
      model.bind('change:state', function () {
        var state = this.get('state');
        var success = this.get('success');
        if (state === 'failure') {
          errorCallback && errorCallback(model);
        } else if (state === 'complete' && success) {
          successCallback && successCallback(model);
        }
      }, model);
    }
  });
};
