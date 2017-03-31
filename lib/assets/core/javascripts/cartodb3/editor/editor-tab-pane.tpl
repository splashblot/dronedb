<nav class="CDB-NavMenu js-theme">
  <ul class="CDB-NavMenu-inner CDB-Text is-semibold CDB-Size-medium js-menu"></ul>
  <button class="Editor-buttonNavigation CDB-Button CDB-Button--small CDB-Button--primary js-add">
    <span class="CDB-Button-Text CDB-Text is-semibold CDB-Size-small u-upperCase">
      <%- _t('editor.button_add') %>
    </span>
  </button>
</nav>
<div class="Editor-content js-content"></div>
<div class="CDB-Text Editor-ListLayer-item-raster">
	<h2 class="CDB-Size-large">Raster tiled layers</h2>
	<div class="raster-tiled-layers-content">
		<span id="message-raster-layer" style="display:none"></span>
		<input type="text" name="rasterurl" placeholder="Layer URL"><button> Add layer</button>
		<p>Layers:</p>
		<ul></ul>
	</div>
</div>
