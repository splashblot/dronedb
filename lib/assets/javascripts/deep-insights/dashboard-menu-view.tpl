<div class="CDB-Dashboard-menuContainer">
  <div class="CDB-Dashboard-menuInner">
    <div class="CDB-Dashboard-menuHeader">
      <ul class="CDB-Dashboard-menuActions">
        <li class="CDB-Dashboard-menuActionsItem">
          <a href="https://twitter.com/share?url=<%- urlWithoutParams %>&text=<%- shortTitle %>" target="_blank" class="u-hintTextColor">
            <i class="CDB-IconFont CDB-IconFont-twitter CDB-Size-large"></i>
          </a>
        </li>
        <li class="CDB-Dashboard-menuActionsItem">
          <a href="http://www.facebook.com/sharer.php?u=<%- urlWithoutParams %>&text=<%- shortTitle %>" target="_blank" class="u-hintTextColor">
            <i class="CDB-IconFont CDB-IconFont-facebook CDB-Size-medium"></i>
          </a>
        </li>
        <% if (inIframe) { %>
          <li class="CDB-Dashboard-menuActionsItem">
            <a href="<%- url %>" target="_blank" class="u-hintTextColor">
              <i class="CDB-IconFont CDB-IconFont-anchor CDB-Size-medium"></i>
            </a>
          </li>
        <% } %>
      </ul>


      <div class="CDB-Dashboard-menuInfo">
        <button class="js-toggle-view">
          <i class="CDB-IconFont CDB-Size-medium CDB-IconFont-rArrowLight Size-large"></i>
        </button>
      </div>

      <div class="CDB-Dashboard-menuTexts CDB-Dashboard-hideMobile">
        <div class="CDB-Dashboard-menuTextInner js-content">
          <button class="js-toggle-view u-actionTextColor CDB-Dashboard-menuTextActions">
            <svg width="10px" height="7px" viewBox="12 13 10 7" version="1.1" xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink">
              <path d="M12,13.5 C12,13.2238576 12.1908338,13 12.4169561,13 L21.5830439,13 C21.8133224,13 22,13.2319336 22,13.5 C22,13.7761424 21.8091662,14 21.5830439,14 L12.4169561,14 C12.1866776,14 12,13.7680664 12,13.5 L12,13.5 L12,13.5 Z M12,16.5 C12,16.2238576 12.1908338,16 12.4169561,16 L21.5830439,16 C21.8133224,16 22,16.2319336 22,16.5 C22,16.7761424 21.8091662,17 21.5830439,17 L12.4169561,17 C12.1866776,17 12,16.7680664 12,16.5 L12,16.5 L12,16.5 Z M12,19.5 C12,19.2238576 12.1908338,19 12.4169561,19 L21.5830439,19 C21.8133224,19 22,19.2319336 22,19.5 C22,19.7761424 21.8091662,20 21.5830439,20 L12.4169561,20 C12.1866776,20 12,19.7680664 12,19.5 L12,19.5 L12,19.5 Z" id="Combined-Shape" stroke="none" fill="#1785fB" fill-rule="evenodd"></path>
            </svg>
          </button>
          <p class="CDB-Dashboard-menuTime CDB-Text CDB-Size-small u-upperCase u-altTextColor u-bSpace--m js-timeAgo">UPDATED <%- updatedAt %></p>
          <div class="CDB-Dashboard-metadata">
            <h1 class="CDB-Dashboard-menuTitle CDB-Dashboard-menuTitle--mobile CDB-Text CDB-Size-huge u-ellipsis js-title" title="<%- title %>"><%- title %></h1>

            <div class="CDB-Dashboard-scrollWrapper js-scroll-wrapper">
              <div class="CDB-Dashboard-scrollContent js-scroll-content">
                <h2 class="CDB-Dashboard-menuDescription CDB-Text CDB-Size-large is-light u-secondaryTextColor js-description"><%= cdb.core.sanitize.html(description) %></h2>
              </div>
            </div>
          </div>
        </div>
      </div>

    </div>

    <div class="CDB-Dashboard-menuFooter">
      <ul>
        <li class="CDB-Dashboard-menuFooterItem ">
          <div class="CDB-Dashboard-menuMedia CDB-Dashboard-menuAvatar">
            <img src="<%- userAvatarURL %>" alt="avatar" class="inline-block"/>
          </div>
          <p class="CDB-Text CDB-Size-medium CDB-Dashboard-menuFooterTxt">Map by <a href="<%- userProfileURL %>" target="_blank"><%- userName %></a></p>
        </li>
      </ul>
    </div>
  </div>
  <div class="CDB-Dashboard-bg js-toggle-view"></div>

  <div class="CDB-Dashboard-menuHeaderMobile">
    <div class="u-flex u-alignStart CDB-Dashboard-menuHeaderMobileInner">
      <button class="js-toggle-view u-actionTextColor CDB-Dashboard-menuHeaderMobileActions">
        <i class="CDB-IconFont CDB-Size-medium CDB-IconFont-rArrowLight Size-large"></i>
      </button>
      <div class="CDB-Dashboard-menuHeaderMobileText">
        <p class="CDB-Dashboard-menuTime CDB-Text CDB-Size-small u-upperCase u-altTextColor u-bSpace--m js-timeAgo">UPDATED <%- updatedAt %></p>
        <h1 class="CDB-Text CDB-Size-large u-ellipsis js-title u-bSpace--xl u-ellipsis"><%- title %></h1>
        <h2 class="CDB-Text CDB-Size-medium u-secondaryTextColor js-description"><%= cdb.core.sanitize.html(description) %></h2>
      </div>
    </div>
  </div>
</div>
