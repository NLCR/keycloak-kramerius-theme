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

    function createIdpButton(idp) {
        const a = document.createElement("a");
        a.href = idp.loginUrl;
        a.className = "kramerius-idp-btn";
        a.id = "social-" + idp.alias;
        a.addEventListener("click", () => saveIdp(idp.alias));

        const name = idp.en_name || idp.displayName;

        if (idp.logo) {
            a.innerHTML = '<span class="idp-name">' + name + '</span>'
                        + '<img class="idp-logo" src="' + idp.logo + '" alt="' + name + '">';
        } else {
            a.innerHTML = '<span class="idp-name">' + name + '</span>';
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

    // collapsible interní login
    const loginToggle = document.getElementById("login-internal-toggle");
    const loginForm = document.getElementById("kc-form-login");
    if (loginToggle && loginForm) {
        loginToggle.addEventListener("click", function() {
            const expanded = loginForm.style.display !== "none";
            loginForm.style.display = expanded ? "none" : "block";
            loginToggle.classList.toggle("open", !expanded);
            loginToggle.setAttribute("aria-expanded", !expanded);
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
    <!-- Collapsible interní login -->
    <div class="kramerius-login-section">
        <button type="button" id="login-internal-toggle" class="kramerius-section-toggle" aria-expanded="false">
            <span class="toggle-icon">&#9654;</span>
            ${msg("loginInternally")}
        </button>
        <form id="kc-form-login" action="${url.loginAction}" method="post" style="display:none;">
            <div class="kramerius-form-inner">
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

    <!-- promoted IDPs -->
    <div id="kc-social-promoted-providers" style="display:none;">
        <ul class="kramerius-idp-list"></ul>
    </div>

    <!-- Nadpis + search + list IdP -->
    <div class="kramerius-login-section">
        <div class="kramerius-institution-header">
            <span class="toggle-icon open">&#9660;</span>
            ${msg("loginWithInstitution")}
        </div>

        <div class="kramerius-search-wrap">
            <svg class="search-icon" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
                <circle cx="11" cy="11" r="8"/><line x1="21" y1="21" x2="16.65" y2="16.65"/>
            </svg>
            <input id="kc-providers-filter" type="search" class="kramerius-search-input"
                   placeholder="${msg('searchPlaceholder')}" autocomplete="off" />
        </div>

        <ul id="kc-providers-list" class="kramerius-idp-list login-pf-list-scrollable"></ul>
    </div>

</div>

</#if>

</@layout.registrationLayout>
