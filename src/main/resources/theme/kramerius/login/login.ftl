<#import "template.ftl" as layout>

<script>
    var idpLoginFullUrl = '${idpLoginFullUrl?no_esc}';
</script>

<script>
document.addEventListener("DOMContentLoaded", function () {

    // generation counter — fix pro duplicitní výsledky při rychlém vyhledávání
    let generation = 0;

    const state = {
        idps: [],
        promotedIdps: [],
        keyword: "",
        first: 0,
        max: 20,
        loading: false,
        reachedEnd: false
    };

    const listEl = document.getElementById("kc-providers-list");
    const searchInput = document.getElementById("kc-providers-filter");

    function buildLoginUrl(idp) {
        return baseUriOrigin + idpLoginFullUrl.replace("/_/", "/" + idp.alias + "/");
    }

    function getSessionParams() {
        return new URL(baseUriOrigin + idpLoginFullUrl).searchParams;
    }

    const sessionParams = getSessionParams();

    const fetchParams = () => ({
        keyword: state.keyword,
        first: state.first,
        max: state.max,
        client_id: sessionParams.get("client_id"),
        tab_id: sessionParams.get("tab_id"),
        session_code: sessionParams.get("session_code")
    });

    function saveIdp(alias) {
        try { localStorage.setItem("savedIdps", alias); } catch(e) {}
    }

    function createIdpButton(idp, extraClass) {
        const a = document.createElement("a");
        a.href = idp.loginUrl;
        a.className = "km-idp-item" + (extraClass ? " " + extraClass : "");
        a.id = "social-" + idp.alias;
        a.addEventListener("click", () => saveIdp(idp.alias));

        const name = idp.en_name || idp.displayName;
        const nameSpan = document.createElement("span");
        nameSpan.className = "km-idp-name";
        nameSpan.textContent = name;
        a.appendChild(nameSpan);

        if (idp.logo) {
            const wrap = document.createElement("span");
            wrap.className = "km-idp-logo-wrap";
            const img = document.createElement("img");
            img.src = idp.logo;
            img.alt = "";
            img.className = "km-idp-logo";
            img.onerror = function() { wrap.style.display = "none"; };
            wrap.appendChild(img);
            a.appendChild(wrap);
        }
        return a;
    }

    async function fetchLogo(idp) {
        try {
            const res = await fetch(baseUri + '/realms/' + realm + '/theme-info/identity-provider-logo/' + idp.alias);
            if (!res.ok) return;
            const data = await res.json();
            idp.logo = data.logo;
            const lang = (new URLSearchParams(window.location.search)).get("kc_locale")
                || navigator.language.split("-")[0];
            idp.en_name = (lang === "en") ? data["en-name"] : null;
        } catch (e) {}
    }

    async function loadIdps() {
        if (state.loading || state.reachedEnd) return;
        state.loading = true;

        const myGeneration = generation; // zachyť aktuální generaci
        const params = new URLSearchParams(fetchParams());

        try {
            const res = await fetch(baseUri + '/realms/' + realm + '/theme-info/identity-providers?' + params);
            const data = await res.json();

            // pokud mezitím přišlo nové vyhledávání, zahoď výsledky
            if (myGeneration !== generation) return;

            state.loading = false;

            if (!data || !Array.isArray(data.identityProviders)) {
                state.reachedEnd = true;
                renderIdps();
                return;
            }

            for (const idp of data.identityProviders) {
                if (myGeneration !== generation) return; // zahoď pokud přišlo nové hledání
                idp.loginUrl = buildLoginUrl(idp);
                await fetchLogo(idp);
                if (myGeneration !== generation) return;
                state.idps.push(idp);
            }

            if (data.identityProviders.length < state.max) state.reachedEnd = true;

        } catch(e) {
            state.loading = false;
            state.reachedEnd = true;
        }

        renderIdps();
        if (state.first === 0) renderLastUsed(state.idps);
    }

    async function loadPromoted() {
        try {
            const res = await fetch(baseUri + '/realms/' + realm + '/theme-info/identity-providers-promoted');
            if (!res.ok) return;
            const data = await res.json();
            if (!data || !Array.isArray(data)) return;

            state.promotedIdps = [];
            for (const idp of data) {
                idp.loginUrl = buildLoginUrl(idp);
                await fetchLogo(idp);
                state.promotedIdps.push(idp);
            }
            renderPromoted();
        } catch(e) {}
    }

    function renderPromoted() {
        const container = document.getElementById("kc-social-promoted-providers");
        if (!container) return;
        const list = container.querySelector("ul");
        if (!list) return;
        list.innerHTML = "";
        state.promotedIdps.forEach(idp => list.appendChild(createIdpButton(idp)));
        container.style.display = state.promotedIdps.length ? "block" : "none";
    }

    function renderIdps() {
        if (!listEl) return;
        listEl.innerHTML = "";
        state.idps.forEach(idp => listEl.appendChild(createIdpButton(idp)));
    }

    function resetSearch(keyword) {
        generation++; // zneplatni všechny probíhající requesty
        state.keyword = keyword;
        state.first = 0;
        state.idps = [];
        state.reachedEnd = false;
        state.loading = false;
        loadIdps();
    }

    // Zobraz poslední použitou instituci
    function renderLastUsed(allIdps) {
        const lastAlias = (() => { try { return localStorage.getItem("savedIdps"); } catch(e) { return null; } })();
        if (!lastAlias) return;
        const idp = allIdps.find(i => i.alias === lastAlias);
        if (!idp) return;

        const container = document.querySelector(".km-last-used");
        if (!container) return;
        container.innerHTML = "";

        const a = createIdpButton(idp, "km-last-used-item");
        a.id = "social-last-" + idp.alias;

        const badge = document.createElement("span");
        badge.className = "km-last-used-badge";
        badge.textContent = "Naposledy";
        a.insertBefore(badge, a.firstChild);
        container.appendChild(a);
    }

    // Clear button na search
    const clearBtn = document.getElementById("kc-search-clear");
    if (clearBtn && searchInput) {
        searchInput.addEventListener("input", function() {
            clearBtn.classList.toggle("visible", searchInput.value.length > 0);
        });
        clearBtn.addEventListener("click", function() {
            searchInput.value = "";
            clearBtn.classList.remove("visible");
            resetSearch("");
            searchInput.focus();
        });
    }
    const loginForm = document.getElementById("kc-form-login");
    if (loginToggle && loginForm) {
        loginToggle.addEventListener("click", function() {
            const expanded = loginForm.style.display !== "none";
            loginForm.style.display = expanded ? "none" : "block";
            loginToggle.classList.toggle("km-open", !expanded);
            loginToggle.setAttribute("aria-expanded", String(!expanded));
        });
    }

    // scroll lazy load
    if (listEl) {
        listEl.addEventListener("scroll", function () {
            if (state.reachedEnd || state.loading) return;
            if (listEl.scrollTop + listEl.clientHeight >= listEl.scrollHeight - 50) {
                state.first += state.max;
                loadIdps();
            }
        });
    }

    // search s debounce
    let searchTimer;
    if (searchInput) {
        searchInput.addEventListener("input", function (e) {
            clearTimeout(searchTimer);
            searchTimer = setTimeout(() => resetSearch(e.target.value), 300);
        });
    }

    // init
    loadIdps();
    loadPromoted();
});
</script>

<@layout.registrationLayout displayMessage=!messagesPerField.existsError('username','password') displayInfo=realm.password && realm.registrationAllowed && !registrationDisabled??; section>

<#if section = "form">

<div id="kc-form">

    <#if realm.password>
    <div class="km-section">
        <button type="button" id="login-internal-toggle" class="km-toggle" aria-expanded="false">
            <span>${msg("loginInternally")}</span>
            <span class="km-toggle-arrow">&#9654;</span>
        </button>
        <form id="kc-form-login" action="${url.loginAction}" method="post" style="display:none;">
            <div class="km-form-body">
                <div class="${properties.kcFormGroupClass!}">
                    <label for="username" class="${properties.kcLabelClass!}">
                        <#if !realm.loginWithEmailAllowed>${msg("username")}<#elseif !realm.registrationEmailAsUsername>${msg("usernameOrEmail")}<#else>${msg("email")}</#if>
                    </label>
                    <input tabindex="1" id="username" class="${properties.kcInputClass!}" name="username"
                           type="text" autocomplete="username"
                           aria-invalid="<#if messagesPerField.existsError('username','password')>true</#if>" />
                </div>
                <div class="${properties.kcFormGroupClass!}">
                    <label for="password" class="${properties.kcLabelClass!}">${msg("password")}</label>
                    <input tabindex="2" id="password" class="${properties.kcInputClass!}" name="password"
                           type="password" autocomplete="current-password"
                           aria-invalid="<#if messagesPerField.existsError('username','password')>true</#if>" />
                </div>
                <div class="${properties.kcFormGroupClass!}">
                    <input tabindex="3" class="${properties.kcButtonClass!} ${properties.kcButtonPrimaryClass!} ${properties.kcButtonBlockClass!} ${properties.kcButtonLargeClass!}"
                           name="login" id="kc-login" type="submit" value="${msg("doLogIn")}"/>
                </div>
            </div>
        </form>
    </div>
    </#if>

    <div id="kc-social-promoted-providers" style="display:none;">
        <div class="km-section"><ul class="km-idp-list"></ul></div>
    </div>

    <div class="km-section">
        <div class="km-inst-header">
            <span class="km-inst-dot"></span>
            ${msg("loginWithInstitution")}
        </div>
        <div class="km-search-wrap">
            <span class="km-search-icon">
                <svg width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" style="display:block;width:16px;height:16px;">
                    <circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/>
                </svg>
            </span>
            <input id="kc-providers-filter" type="search" class="km-search-input"
                   placeholder="${msg('searchPlaceholder')}" autocomplete="off" />
            <button type="button" id="kc-search-clear" class="km-search-clear" aria-label="Vymazat">&#x2715;</button>
        </div>
        <div class="km-last-used"></div>
        <ul id="kc-providers-list" class="km-idp-list"></ul>
    </div>

</div>

</#if>

</@layout.registrationLayout>
