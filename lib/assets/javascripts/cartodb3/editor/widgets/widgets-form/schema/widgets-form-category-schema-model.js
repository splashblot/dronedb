var _ = require('underscore');
var WidgetsFormBaseSchema = require('./widgets-form-base-schema-model');

module.exports = WidgetsFormBaseSchema.extend({

  defaults: {
    schema: {},
    aggregate: {
      attribute: '',
      operator: 'count'
    }
  },

  initialize: function (attrs, opts) {
    if (!opts.columnOptionsFactory) throw new Error('columnOptionsFactory is required');
    this._columnOptionsFactory = opts.columnOptionsFactory;
    this.on('change:aggregate', this._updateAggregation, this);
    this.on('change:column', this.updateSchema, this);

    this._updateAggregation();

    WidgetsFormBaseSchema.prototype.initialize.apply(this, arguments);
  },

  getFields: function () {
    var fields = ['column', 'aggregate', 'prefix', 'suffix'];

    return {
      data: fields.join(','),
      style: 'sync_on_bbox_change'
    };
  },

  _updateAggregation: function () {
    var aggregate = this.get('aggregate');
    if (aggregate === undefined) {
      this.set({
        aggregation: 'count',
        aggregation_column: ''
      });
    } else {
      this.set({
        aggregation_column: aggregate.attribute,
        aggregation: aggregate.operator
      });
    }

    this.updateSchema();
  },

  updateSchema: function () {
    var columnOptions = this._columnOptionsFactory.create(this.get('column'));
    var helpMsg = this._columnOptionsFactory.unavailableColumnsHelpMessage();
    var aggregationOptions = _.filter(columnOptions, function (column) {
      return column.type === 'number';
    });

    this.schema = _.extend(this.schema, {
      column: {
        type: 'Select',
        title: _t('editor.widgets.widgets-form.data.aggregate-by'),
        options: columnOptions,
        help: helpMsg,
        editorAttrs: {
          disabled: this._columnOptionsFactory.areColumnsUnavailable()
        }
      },
      aggregate: {
        type: 'Operators',
        title: _t('editor.widgets.widgets-form.data.operation'),
        options: aggregationOptions,
        editorAttrs: {
          showSearch: false
        }
      },
      suffix: {
        type: 'EnablerEditor',
        title: '',
        label: _t('editor.widgets.widgets-form.data.suffix'),
        editor: {
          type: 'Text'
        }
      },
      prefix: {
        type: 'EnablerEditor',
        title: '',
        label: _t('editor.widgets.widgets-form.data.prefix'),
        editor: {
          type: 'Text'
        }
      }
    });
  },

  canSave: function () {
    var aggregation = this.get('aggregation');
    var aggregationColumn = this.get('aggregation_column');
    var canSave = false;

    if (aggregation === 'count') {
      canSave = true;
    } else {
      canSave = !!(aggregation && aggregationColumn);
    }

    return canSave;
  }

});
