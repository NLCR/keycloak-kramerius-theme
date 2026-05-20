<#import "template.ftl" as layout>
<script>var idpLoginFullUrl = '${idpLoginFullUrl?no_esc}';</script>
<script>
document.addEventListener("DOMContentLoaded", function () {

    var state = { idps: [] };
    var listEl      = document.getElementById("kc-providers-list");
    var searchInput = document.getElementById("kc-providers-filter");
    var clearBtn    = document.getElementById("kc-search-clear");
    var loginToggle = document.getElementById("login-internal-toggle");
    var loginForm   = document.getElementById("kc-form-login");

    function buildLoginUrl(idp) {
        return new URL(baseUri).origin + idpLoginFullUrl.replace("/_/", "/" + idp.alias + "/");
    }
    function sessionParam(k) {
        return new URL(new URL(baseUri).origin + idpLoginFullUrl).searchParams.get(k);
    }
    function saveIdp(idp) {
        try { localStorage.setItem("lastIdp", JSON.stringify({ alias: idp.alias, displayName: idp.en_name || idp.displayName, logo: idp.logo || null })); } catch(e) {}
    }
    function getLastIdp() {
        try { return JSON.parse(localStorage.getItem("lastIdp")); } catch(e) { return null; }
    }

    function createIdpButton(idp, extraClass) {
        var a = document.createElement("a");
        a.href = idp.loginUrl;
        a.className = "km-idp-item" + (extraClass ? " " + extraClass : "");
        a.id = "social-" + idp.alias;
        a.addEventListener("click", function() { saveIdp(idp); });
        var nameSpan = document.createElement("span");
        nameSpan.className = "km-idp-name";
        nameSpan.textContent = idp.en_name || idp.displayName;
        a.appendChild(nameSpan);
        if (idp.logo) {
            var wrap = document.createElement("span");
            wrap.className = "km-logo-wrap";
            var img = document.createElement("img");
            img.src = idp.logo;
            img.alt = "";
            img.className = "km-logo" + (idp.logoClass ? " km-logo-" + idp.logoClass : "");
            img.onerror = function() { wrap.style.display = "none"; };
            wrap.appendChild(img);
            a.appendChild(wrap);
        }
        return a;
    }

    function updateIdpButton(idp) {
        ["social-" + idp.alias, "social-last-" + idp.alias].forEach(function(id) {
            var a = document.getElementById(id);
            if (!a) return;
            var ns = a.querySelector(".km-idp-name");
            if (ns) ns.textContent = idp.en_name || idp.displayName;
            if (idp.logo && !a.querySelector(".km-logo-wrap")) {
                var wrap = document.createElement("span");
                wrap.className = "km-logo-wrap";
                var img = document.createElement("img");
                img.src = idp.logo;
                img.alt = "";
                img.className = "km-logo" + (idp.logoClass ? " km-logo-" + idp.logoClass : "");
                img.onerror = function() { wrap.style.display = "none"; };
                wrap.appendChild(img);
                a.appendChild(wrap);
            }
        });
    }

    async function fetchLogo(idp) {
        try {
            var res = await fetch(baseUri.replace(/\/$/, "") + "/realms/" + realm + "/theme-info/identity-provider-logo/" + idp.alias);
            if (!res.ok) return;
            var data = await res.json();
            idp.logo = data.logo || null;
            idp.logoClass = data["logo-class"] || null;
            var lang = (new URLSearchParams(window.location.search)).get("kc_locale") || navigator.language.split("-")[0];
            idp.en_name = (lang === "en" && data["en-name"]) ? data["en-name"] : null;
            updateIdpButton(idp);
        } catch(e) {}
    }

    async function loadLogosInBatches(idps, batchSize) {
        for (var i = 0; i < idps.length; i += batchSize) {
            await Promise.all(idps.slice(i, i + batchSize).map(fetchLogo));
        }
    }

    async function loadAllIdps() {
        var params = new URLSearchParams({
            keyword: "", first: 0, max: 10000,
            client_id:    sessionParam("client_id")    || "",
            tab_id:       sessionParam("tab_id")       || "",
            session_code: sessionParam("session_code") || ""
        });
        try {
            var res  = await fetch(baseUri.replace(/\/$/, "") + "/realms/" + realm + "/theme-info/identity-providers?" + params);
            var data = await res.json();
            if (!data || !Array.isArray(data.identityProviders)) return;
            data.identityProviders.forEach(function(idp) {
                idp.loginUrl = buildLoginUrl(idp);
                state.idps.push(idp);
            });
        } catch(e) { return; }

        renderIdps(state.idps);
        renderLastUsed();
        loadLogosInBatches(state.idps, 3);
    }

    function renderIdps(idps) {
        if (!listEl) return;
        listEl.innerHTML = "";
        idps.forEach(function(idp) { listEl.appendChild(createIdpButton(idp)); });
    }

    function renderFiltered(keyword) {
        var kw = keyword.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
        var filtered = state.idps.filter(function(idp) {
            var name = (idp.displayName || "").toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");
            return name.includes(kw) || (idp.alias || "").toLowerCase().includes(kw);
        });
        renderIdps(filtered);
    }

    function renderLastUsed() {
        var stored = getLastIdp();
        if (!stored) return;
        var container = document.getElementById("km-last-used");
        if (!container) return;
        var idp = Object.assign({}, stored);
        idp.loginUrl = buildLoginUrl(idp);
        container.innerHTML = "";
        var btn = createIdpButton(idp, "km-last-used-item");
        btn.id = "social-last-" + idp.alias;
        var badge = document.createElement("span");
        badge.className = "km-last-badge";
        badge.textContent = "Naposledy";
        btn.insertBefore(badge, btn.firstChild);
        container.appendChild(btn);
    }

    if (loginToggle && loginForm) {
        loginToggle.addEventListener("click", function() {
            var open = loginForm.style.display !== "none";
            loginForm.style.display = open ? "none" : "block";
            loginToggle.classList.toggle("km-open", !open);
            loginToggle.setAttribute("aria-expanded", String(!open));
        });
    }
    if (loginForm && loginForm.dataset.hasErrors === "true") {
        loginForm.style.display = "block";
        if (loginToggle) { loginToggle.classList.add("km-open"); loginToggle.setAttribute("aria-expanded", "true"); }
    }

    if (clearBtn && searchInput) {
        searchInput.addEventListener("input", function() { clearBtn.style.display = searchInput.value ? "flex" : "none"; });
        clearBtn.addEventListener("click", function() {
            searchInput.value = ""; clearBtn.style.display = "none";
            renderIdps(state.idps); searchInput.focus();
        });
    }

    var searchTimer;
    if (searchInput) {
        searchInput.addEventListener("input", function(e) {
            clearTimeout(searchTimer);
            searchTimer = setTimeout(function() {
                var kw = e.target.value.trim();
                if (kw) renderFiltered(kw); else renderIdps(state.idps);
            }, 200);
        });
    }

    renderLastUsed();
    loadAllIdps();
});
</script>

<@layout.registrationLayout displayMessage=true displayInfo=realm.password && realm.registrationAllowed && !registrationDisabled??; section>
<#if section = "form">
<div id="kc-form">

    <#if realm.password>
    <div class="km-section">
        <button type="button" id="login-internal-toggle" class="km-toggle" aria-expanded="false">
            <span>${msg("loginInternally")}</span>
            <span class="km-arrow">&#9654;</span>
        </button>
        <form id="kc-form-login" action="${url.loginAction}" method="post"
              style="display:none"
              data-has-errors="<#if messagesPerField.existsError('username','password')>true<#else>false</#if>">
            <div class="km-form-body">
                <div class="${properties.kcFormGroupClass!}">
                    <label for="username" class="${properties.kcLabelClass!}">
                        <#if !realm.loginWithEmailAllowed>${msg("username")}<#elseif !realm.registrationEmailAsUsername>${msg("usernameOrEmail")}<#else>${msg("email")}</#if>
                    </label>
                    <input tabindex="1" id="username" class="${properties.kcInputClass!} km-input"
                           name="username" type="text" autocomplete="username"
                           aria-invalid="<#if messagesPerField.existsError('username','password')>true</#if>"/>
                </div>
                <div class="${properties.kcFormGroupClass!}">
                    <label for="password" class="${properties.kcLabelClass!}">${msg("password")}</label>
                    <input tabindex="2" id="password" class="${properties.kcInputClass!} km-input"
                           name="password" type="password" autocomplete="current-password"
                           aria-invalid="<#if messagesPerField.existsError('username','password')>true</#if>"/>
                </div>
                <div class="km-submit-row">
                    <input tabindex="3" class="${properties.kcButtonClass!} ${properties.kcButtonPrimaryClass!} ${properties.kcButtonBlockClass!} ${properties.kcButtonLargeClass!}"
                           name="login" id="kc-login" type="submit" value="${msg("doLogIn")}"/>
                </div>
            </div>
        </form>
    </div>
    </#if>

    <div class="km-section">
        <div class="km-inst-header">
            <span class="km-dot"></span>
            ${msg("loginWithInstitution")}
        </div>
        <div class="km-search-row">
            <svg width="15" height="15" viewBox="0 0 24 24" fill="none" stroke="#94a3b8" stroke-width="2.5"><circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/></svg>
            <input id="kc-providers-filter" type="search" class="km-search"
                   placeholder="${msg('searchPlaceholder')}" autocomplete="off"/>
            <button type="button" id="kc-search-clear" class="km-clear" style="display:none" aria-label="Vymazat">&#215;</button>
        </div>
        <div id="km-last-used"></div>
        <ul id="kc-providers-list" class="km-list login-pf-list-scrollable"></ul>
    </div>

</div>
</#if>
</@layout.registrationLayout>
