<#import "template.ftl" as layout>

<script>
    var idpLoginFullUrl = '${idpLoginFullUrl?no_esc}';
</script>

<script>
document.addEventListener("DOMContentLoaded", function () {

    const state = {
        idps: [],
        promotedIdps: [],
        first: 0,
        max: 20,
        loading: false,
        reachedEnd: false
    };

    const listEl = document.getElementById("kc-providers-list");

    function buildLoginUrl(idp) {
        return baseUriOrigin + idpLoginFullUrl.replace("/_/", "/" + idp.alias + "/");
    }

    async function fetchLogo(idp) {
        try {
            const res = await fetch(baseUri + '/realms/' + realm + '/theme-info/identity-provider-logo/' + idp.alias);
            const data = await res.json();
            idp.logo = data.logo;
        } catch (e) {}
    }

    function createIdp(idp) {
        const a = document.createElement("a");
        a.href = idp.loginUrl;
        a.id = "social-" + idp.alias;

        const name = idp.displayName;

        a.innerHTML = idp.iconClasses
            ? '<i class="' + idp.iconClasses + '"></i> <span>' + name + '</span>'
            : '<span>' + name + '</span>';

        return a;
    }

    async function loadIdps() {
        if (state.loading || state.reachedEnd) return;
        state.loading = true;

        const params = new URLSearchParams({
            first: state.first,
            max: state.max
        });

        const res = await fetch(baseUri + '/realms/' + realm + '/theme-info/identity-providers?' + params);
        const data = await res.json();

        state.loading = false;

        if (!data.identityProviders) return;

        for (const idp of data.identityProviders) {
            idp.loginUrl = buildLoginUrl(idp);
            await fetchLogo(idp);
            state.idps.push(idp);
        }

        render();
    }

    async function loadPromoted() {
        const res = await fetch(baseUri + '/realms/' + realm + '/theme-info/identity-providers-promoted');
        const data = await res.json();

        if (!data || !Array.isArray(data)) return;

        state.promotedIdps = data.map(idp => {
            idp.loginUrl = buildLoginUrl(idp);
            return idp;
        });

        render();
    }

    function render() {
        if (!listEl) return;

        listEl.innerHTML = "";

        state.promotedIdps.forEach(idp => {
            listEl.appendChild(createIdp(idp));
        });

        state.idps.forEach(idp => {
            listEl.appendChild(createIdp(idp));
        });
    }

    if (listEl) {
        listEl.addEventListener("scroll", () => {
            if (state.loading || state.reachedEnd) return;

            if (listEl.scrollTop + listEl.clientHeight >= listEl.scrollHeight - 50) {
                state.first += state.max;
                loadIdps();
            }
        });
    }

    loadIdps();
    loadPromoted();

});
</script>

<@layout.registrationLayout displayMessage=!messagesPerField.existsError('username') displayInfo=(realm.password && realm.registrationAllowed && !registrationDisabled??); section>

<#if section = "form">

<div id="kc-form">

    <form id="kc-form-login" action="${url.loginAction}" method="post">
        <input id="username" name="username" type="text" autofocus />
        <input id="password" name="password" type="password" />
        <input type="submit" value="${msg("doLogIn")}" />
    </form>

    <hr/>

    <ul id="kc-providers-list"></ul>

</div>

</#if>

</@layout.registrationLayout>
