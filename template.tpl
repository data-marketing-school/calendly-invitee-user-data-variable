___TERMS_OF_SERVICE___

By creating or modifying this file you agree to Google Tag Manager's Community
Template Gallery Developer Terms of Service available at
https://developers.google.com/tag-manager/gallery-tos (or such other URL as
Google may provide), as modified from time to time.


___INFO___

{
  "type": "MACRO",
  "id": "cvt_temp_public_id",
  "version": 1,
  "securityGroups": [],
  "displayName": "Calendly - Invitee user data",
  "description": "Get first name, last name, email address and phone number (when applicable) of the invitee.",
  "containerContexts": [
    "SERVER"
  ]
}


___TEMPLATE_PARAMETERS___

[
  {
    "type": "TEXT",
    "name": "personalAccessToken",
    "displayName": "Personal Access Token",
    "simpleValueType": true,
    "valueHint": "eyJraWqiOiIxY2UxZTEzNjE3ZGNeNzY1djNjZWJjY2Y4ZGM13mamYThhNjVlNjg0bDIzZjdjMzJi",
    "help": "In Calendly, go to \u003cb\u003eIntegrations \u0026 apps\u003c/b\u003e, then click on \u003cb\u003eAPI \u0026 Webhooks\u003c/b\u003e card, then click on \u003cb\u003eGenerate New Token\u003c/b\u003e. Copy the token and paste it here."
  },
  {
    "type": "TEXT",
    "name": "inviteeUri",
    "displayName": "Invitee URI",
    "simpleValueType": true,
    "valueHint": "https://api.calendly.com/scheduled_events/38ca1dcc-c2ce-4eb2-9236-04cbf683e341/invitees/fbb8016e-0368-41a0-ba10-a35a719689bd",
    "valueValidators": [
      {
        "type": "NON_EMPTY"
      }
    ]
  }
]


___SANDBOXED_JS_FOR_SERVER___

const sendHttpRequest = require('sendHttpRequest');
const JSON = require('JSON');
const Promise = require('Promise');
const logToConsole = require('logToConsole');

return Promise.create((resolve) => {
  sendHttpRequest(data.inviteeUri, {
    method: "GET",
    headers: {
      'Authorization': 'Bearer ' + data.personalAccessToken
    }
  }).then((result) => {
    if(result.statusCode >= 200 && result.statusCode < 300) {
      
      let user_data = {};
      user_data.address = {};
      
      let response = JSON.parse(result.body).resource;
      if(response.email) {
        user_data.email_address = response.email;
      }
      
      if(response.text_reminder_number) {
        user_data.phone_number = response.text_reminder_number;
      }
      
      if(response.first_name) {
        user_data.address.first_name = response.first_name;
      }
      
      if(response.last_name) {
        user_data.address.last_name = response.last_name;
      }
      
      if(response.name) {
        let fn = response.name.split(' ')[0];
        let ln = response.name.split(' ')[1];
        user_data.address.first_name = fn;
        user_data.address.last_name = ln;
      }
      
      resolve(user_data);
      
    } else {
      logToConsole(result.statusCode + ' - ' + result.body);
    }
    
  }).catch((error) => {
    logToConsole("Error: " + error);
  });
});


___SERVER_PERMISSIONS___

[
  {
    "instance": {
      "key": {
        "publicId": "send_http",
        "versionId": "1"
      },
      "param": [
        {
          "key": "allowedUrls",
          "value": {
            "type": 1,
            "string": "specific"
          }
        },
        {
          "key": "urls",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 1,
                "string": "https://api.calendly.com/scheduled_events/*/invitees/*"
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "logging",
        "versionId": "1"
      },
      "param": [
        {
          "key": "environments",
          "value": {
            "type": 1,
            "string": "debug"
          }
        }
      ]
    },
    "isRequired": true
  }
]


___TESTS___

scenarios: []


___NOTES___

Created on 31/12/2025, 17:10:01


