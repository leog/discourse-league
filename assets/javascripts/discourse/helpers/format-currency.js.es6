import { registerUnbound } from 'discourse-common/lib/helpers';

registerUnbound('format-currency', function(val) {
  val = val.toString();
  if (Discourse.SiteSettings.league_currency == "CAD"){
    var amount = val.split(".");
    if (amount[1] == undefined){
      amount[1] = "00";
    }
    else{
      amount[1] = (amount[1] + "000").substring(0,2);
    }
    return I18n.t('league.currency.CAD') + amount[0] + "," + amount[1];
  }
  else if (Discourse.SiteSettings.league_currency == "EUR"){
    var amount = val.split(".");
    if (amount[1] == undefined){
      amount[1] = "00";
    }
    else{
      amount[1] = (amount[1] + "000").substring(0,2);
    }
    return I18n.t('league.currency.EUR') + amount[0] + "," + amount[1];
  }
  else if (Discourse.SiteSettings.league_currency == "GBP"){
    var amount = val.split(".");
    if (amount[1] == undefined){
      amount[1] = "00";
    }
    else{
      amount[1] = (amount[1] + "000").substring(0,2);
    }
    return I18n.t('league.currency.GBP') + amount[0] + "," + amount[1];
  }
  else if (Discourse.SiteSettings.league_currency == "USD"){
    var amount = val.split(".");
    if (amount[1] == undefined){
      amount[1] = "00";
    }
    else{
      amount[1] = (amount[1] + "000").substring(0,2);
    }
    return I18n.t('league.currency.USD') + amount[0] + "." + amount[1];
  };
});