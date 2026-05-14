<#import "template.ftl" as layout>
<script>var idpLoginFullUrl = '${idpLoginFullUrl?no_esc}';</script>
<script>
document.addEventListener("DOMContentLoaded", function () {

    var generation = 0;
    var state = { idps: [], first: 0, max: 20, keyword: "", loading: false, reachedEnd: false };

    var listEl      = document.getElementById("kc-providers-list");
    var searchInput = document.getElementById("kc-providers-filter");
    var clearBtn    = document.getElementById("kc-search-clear");
    var loginToggle = document.getElementById("login-internal-toggle");
    var loginForm   = document.getElementById("kc-form-login");

    /* ---- helpers ---- */
    function buildLoginUrl(idp) {
        return new URL(baseUri).origin + idpLoginFullUrl.replace("/_/", "/" + idp.alias + "/");
    }
    function sessionParam(k) {
        return new URL(new URL(baseUri).origin + idpLoginFullUrl).searchParams.get(k);
    }
    function saveIdp(idp) {
        try {
            localStorage.setItem("lastIdp", JSON.stringify({
                alias: idp.alias,
                displayName: idp.en_name || idp.displayName,
                logo: idp.logo || null,
                loginUrl: idp.loginUrl
            }));
        } catch(e) {}
    }
    function getLastIdp() {
        try { return JSON.parse(localStorage.getItem("lastIdp")); } catch(e) { return null; }
    }

    /* ---- create button ---- */
    function createIdpButton(idp, extraClass) {
        var a = document.createElement("a");
        a.href = idp.loginUrl;
        a.className = "km-idp-item" + (extraClass ? " " + extraClass : "");
        a.id = "social-" + idp.alias;
        a.addEventListener("click", function() { saveIdp(idp); });

        var name = idp.en_name || idp.displayName;

        var nameSpan = document.createElement("span");
        nameSpan.className = "km-idp-name";
        nameSpan.textContent = name;
        a.appendChild(nameSpan);

        if (idp.logo) {
            var wrap = document.createElement("span");
            wrap.className = "km-logo-wrap";
            var img = document.createElement("img");
            img.src = idp.logo;
            img.alt = "";
            img.className = "km-logo";
            img.onerror = function() { wrap.style.display = "none"; };
            wrap.appendChild(img);
            a.appendChild(wrap);
        }
        return a;
    }

    /* ---- fetch logo ---- */
    async function fetchLogo(idp) {
        try {
            var res = await fetch(baseUri.replace(/\/$/, "") + "/realms/" + realm + "/theme-info/identity-provider-logo/" + idp.alias);
            if (!res.ok) return;
            var data = await res.json();
            idp.logo = data.logo || null;
            var lang = (new URLSearchParams(window.location.search)).get("kc_locale") || navigator.language.split("-")[0];
            idp.en_name = (lang === "en" && data["en-name"]) ? data["en-name"] : null;
        } catch(e) {}
    }

    /* ---- load idps ---- */
    async function loadIdps() {
        if (state.loading || state.reachedEnd) return;
        state.loading = true;
        var gen = generation;

        var params = new URLSearchParams({
            keyword: state.keyword, first: state.first, max: state.max,
            client_id:    sessionParam("client_id")    || "",
            tab_id:       sessionParam("tab_id")       || "",
            session_code: sessionParam("session_code") || ""
        });

        try {
            var res  = await fetch(baseUri.replace(/\/$/, "") + "/realms/" + realm + "/theme-info/identity-providers?" + params);
            var data = await res.json();
            if (gen !== generation) return;
            state.loading = false;

            if (!data || !Array.isArray(data.identityProviders) || data.identityProviders.length === 0) {
                state.reachedEnd = true;
            } else {
                for (var i = 0; i < data.identityProviders.length; i++) {
                    if (gen !== generation) return;
                    var idp = data.identityProviders[i];
                    idp.loginUrl = buildLoginUrl(idp);
                    await fetchLogo(idp);
                    if (gen !== generation) return;
                    state.idps.push(idp);
                }
                if (data.identityProviders.length < state.max) state.reachedEnd = true;
            }
        } catch(e) {
            state.loading = false;
            state.reachedEnd = true;
        }

        renderIdps();
        // Aktualizuj last used čerstvými daty pokud je v první stránce
        if (state.first === 0) {
            var stored = getLastIdp();
            if (stored) {
                var fresh = state.idps.find(function(i) { return i.alias === stored.alias; });
                if (fresh) renderLastUsed(fresh);
            }
        }
    }

    /* ---- render ---- */
    function renderIdps() {
        if (!listEl) return;
        listEl.innerHTML = "";
        state.idps.forEach(function(idp) { listEl.appendChild(createIdpButton(idp)); });
    }

    function renderLastUsed(idpOverride) {
        var stored = getLastIdp();
        if (!stored) return;
        var container = document.getElementById("km-last-used");
        if (!container) return;

        // Použij override (čerstvá data z API) nebo uložená data
        var idp = idpOverride || stored;
        if (!idp.loginUrl && stored.loginUrl) idp.loginUrl = stored.loginUrl;
        if (!idp.loginUrl) return;

        container.innerHTML = "";
        var btn = createIdpButton(idp, "km-last-used-item");
        var badge = document.createElement("span");
        badge.className = "km-last-badge";
        badge.textContent = "Naposledy";
        btn.insertBefore(badge, btn.firstChild);
        container.appendChild(btn);
    }

    /* ---- reset search ---- */
    function resetSearch(kw) {
        generation++;
        state.keyword = kw;
        state.first   = 0;
        state.idps    = [];
        state.reachedEnd = false;
        state.loading    = false;
        renderIdps();
        loadIdps();
    }

    /* ---- toggle interní login ---- */
    if (loginToggle && loginForm) {
        loginToggle.addEventListener("click", function() {
            var open = loginForm.style.display !== "none";
            loginForm.style.display = open ? "none" : "block";
            loginToggle.classList.toggle("km-open", !open);
            loginToggle.setAttribute("aria-expanded", String(!open));
        });
    }

    /* ---- clear search ---- */
    if (clearBtn && searchInput) {
        searchInput.addEventListener("input", function() {
            clearBtn.style.display = searchInput.value ? "flex" : "none";
        });
        clearBtn.addEventListener("click", function() {
            searchInput.value = "";
            clearBtn.style.display = "none";
            resetSearch("");
            searchInput.focus();
        });
    }

    /* ---- scroll lazy load ---- */
    if (listEl) {
        listEl.addEventListener("scroll", function() {
            if (state.reachedEnd || state.loading) return;
            if (listEl.scrollTop + listEl.clientHeight >= listEl.scrollHeight - 60) {
                state.first += state.max;
                loadIdps();
            }
        });
    }

    /* ---- search debounce ---- */
    var searchTimer;
    if (searchInput) {
        searchInput.addEventListener("input", function(e) {
            clearTimeout(searchTimer);
            searchTimer = setTimeout(function() { resetSearch(e.target.value); }, 300);
        });
    }

    /* ---- init ---- */
    renderLastUsed(); // okamžitě z localStorage
    loadIdps();
});
</script>

<@layout.registrationLayout displayMessage=!messagesPerField.existsError('username','password') displayInfo=realm.password && realm.registrationAllowed && !registrationDisabled??; section>
<#if section = "form">
<div id="kc-form">

    <#if realm.password>
    <div class="km-section">
        <button type="button" id="login-internal-toggle" class="km-toggle" aria-expanded="false">
            <span>${msg("loginInternally")}</span>
            <span class="km-arrow">&#9654;</span>
        </button>
        <form id="kc-form-login" action="${url.loginAction}" method="post" style="display:none">
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
    <br>
</div>
</#if>
</@layout.registrationLayout>
