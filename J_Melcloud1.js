var MelCloud = (function(api) {
    // unique identifier for this plugin...
    var uuid = '83a354d3-ebf2-4e66-82fb-5783e7062702';

    function maFonction() {
        //	 window.alert("Hello la France!!");
        html = '<p style="margin-top:10px; margin-left:10px">No users to notify</p>';

        api.setCpanelContent(html);
    }

    myModule = {
        uuid: uuid,



        maFonction: maFonction
    };

    return myModule;
})(api);