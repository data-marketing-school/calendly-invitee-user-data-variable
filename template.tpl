___TERMS_OF_SERVICE___

By creating or modifying this file you agree to Google Tag Manager's Community
Template Gallery Developer Terms of Service available at
https://developers.google.com/tag-manager/gallery-tos (or such other URL as
Google may provide), as modified from time to time.


___INFO___

{
  "type": "MACRO",
  "id": "cvt_5TWHR",
  "version": 1,
  "displayName": "Enrich from Calendly API by DMS",
  "description": "Calls the Calendly API and returns a single object with the scheduled event details, the invitee user data (email, phone, first and last name), the booking form and routing form answers, the UTM track",
  "containerContexts": [
    "SERVER"
  ],
  "securityGroups": []
}


___TEMPLATE_PARAMETERS___

[
  {
    "type": "TEXT",
    "name": "personalAccessToken",
    "displayName": "Personal Access Token",
    "simpleValueType": true,
    "valueHint": "eyJraWqiOiIxY2UxZTEzNjE3ZGNeNzY1djNjZWJjY2Y4ZGM13mamYThhNjVlNjg0bDIzZjdjMzJi",
    "help": "Your Calendly API token, used to authenticate every request.\u003cbr\u003e\u003cbr\u003eIn Calendly, go to \u003cb\u003eIntegrations \u0026 apps\u003c/b\u003e, open the \u003cb\u003eAPI \u0026 Webhooks\u003c/b\u003e card, then click \u003cb\u003eGenerate New Token\u003c/b\u003e. Copy the token and paste it here.\u003cbr\u003e\u003cbr\u003e\u003cb\u003eRequired scopes\u003c/b\u003e\u003cbr\u003e\u003cb\u003escheduled_events:read\u003c/b\u003e — the event and the invitee (mandatory).\u003cbr\u003e\u003cb\u003erouting_forms:read\u003c/b\u003e — the routing form answers (optional: without it the rest of the data is still returned and the routing form error is logged in the preview console).\u003cbr\u003e\u003cbr\u003e\u003cb\u003eRole\u003c/b\u003e\u003cbr\u003eA token created by a regular member only reads that member\u0027s own meetings. To enrich bookings from several hosts, use a token created by an \u003cb\u003eadmin\u003c/b\u003e or an \u003cb\u003eowner\u003c/b\u003e of the organization, otherwise some invitees return 403 and others do not.",
    "valueValidators": [
      {
        "type": "NON_EMPTY"
      }
    ]
  },
  {
    "type": "TEXT",
    "name": "inviteeUri",
    "displayName": "Invitee URI",
    "simpleValueType": true,
    "valueHint": "https://api.calendly.com/scheduled_events/38ca1dcc-c2ce-4eb2-9236-04cbf683e341/invitees/fbb8016e-0368-41a0-ba10-a35a719689bd",
    "help": "The invitee to look up. This URI can come from either source:\u003cbr\u003e\u003cbr\u003e\u003cb\u003e1. Calendly webhook\u003c/b\u003e (server-side) — the \u003cb\u003epayload.uri\u003c/b\u003e value of an \u003cb\u003einvitee.created\u003c/b\u003e or \u003cb\u003einvitee.canceled\u003c/b\u003e notification received by a client in your server container.\u003cbr\u003e\u003cbr\u003e\u003cb\u003e2. Online tracking\u003c/b\u003e (web) — the Calendly listener sends a \u003cb\u003ecalendly.event_scheduled\u003c/b\u003e with \u003cb\u003einvitee_uri\u003c/b\u003e event parameter. Push it to the dataLayer and forward it to the server container, where it arrives in the event data as \u003cb\u003einvitee_uri\u003c/b\u003e. That message only exposes the event and invitee URIs, so this variable is what turns them into usable data.\u003cbr\u003e\u003cbr\u003eIn both cases, read the value with an \u003cb\u003eEvent Data\u003c/b\u003e variable (key \u003cb\u003einvitee_uri\u003c/b\u003e for the online tracking option). It must have this shape:\u003cbr\u003e\u003cb\u003ehttps://api.calendly.com/scheduled_events/{event_uuid}/invitees/{invitee_uuid}\u003c/b\u003e\u003cbr\u003e\u003cbr\u003eThe event UUID is read from this URI, so no separate event field is needed. Anything else returns \u003cb\u003eundefined\u003c/b\u003e and logs the reason in the preview console.\u003cbr\u003e\u003cbr\u003e\u003cb\u003eNote:\u003c/b\u003e a reschedule creates a new invitee, so this URI is not stable across reschedules. The previous one is available on the invitee resource itself.",
    "valueValidators": [
      {
        "type": "NON_EMPTY"
      }
    ]
  }
]


___SANDBOXED_JS_FOR_SERVER___

const JSON = require('JSON');
const Object = require('Object');
const Promise = require('Promise');
const getType = require('getType');
const logToConsole = require('logToConsole');
const sendHttpRequest = require('sendHttpRequest');

const EVENTS_ENDPOINT = 'https://api.calendly.com/scheduled_events/';
const PHONE_SEPARATORS = '()._-+/ ';

const authHeaders = {
  'Authorization': 'Bearer ' + data.personalAccessToken
};

/*
 * Helpers
 */

function resolved(value) {
  return Promise.create((resolve) => {
    resolve(value);
  });
}

// Never rejects: a failed call is logged and resolved as undefined, so a
// rejected promise can never escape and be reported as an unhandled rejection.
function callCalendly(url) {
  return Promise.create((resolve) => {
    sendHttpRequest(url, {
      method: 'GET',
      headers: authHeaders
    }).then((result) => {
      const body = JSON.parse(result.body);

      if (result.statusCode >= 200 && result.statusCode < 300 && body && body.resource) {
        resolve(body.resource);
        return;
      }

      const message = body && body.message ? body.message : 'unexpected Calendly API response';
      logToConsole('Enrich from Calendly API - ' + url + ': ' + result.statusCode + ' - ' + message);
      resolve(undefined);
    }).catch((error) => {
      logToConsole('Enrich from Calendly API - ' + url + ': ' + error);
      resolve(undefined);
    });
  });
}

function getEventUri(inviteeUri) {
  // https://api.calendly.com/scheduled_events/{event_uuid}/invitees/{invitee_uuid}
  const parts = inviteeUri.split('/');
  if (parts.length < 5 || parts[3] !== 'scheduled_events' || !parts[4]) {
    return undefined;
  }
  return EVENTS_ENDPOINT + parts[4];
}

// Returns the phone number as digits (with a leading + when present), or
// undefined when the value cannot be a phone number.
// When strict is true, any character that is neither a digit nor a usual phone
// separator disqualifies the value (used to detect the phone answer among the
// free-text answers of the booking form).
function toPhoneNumber(value, strict) {
  if (getType(value) !== 'string') {
    return undefined;
  }

  const digits = '0123456789';
  const hasLeadingPlus = value.trim().indexOf('+') === 0;
  let cleaned = '';
  let onlyPhoneCharacters = true;

  value.split('').forEach((character) => {
    if (digits.indexOf(character) !== -1) {
      cleaned = cleaned + character;
    } else if (PHONE_SEPARATORS.indexOf(character) === -1) {
      onlyPhoneCharacters = false;
    }
  });

  if (strict && !onlyPhoneCharacters) {
    return undefined;
  }

  if (cleaned.length < 7 || cleaned.length > 15) {
    return undefined;
  }

  return hasLeadingPlus ? '+' + cleaned : cleaned;
}

function mergeObjects(obj1, obj2) {
  const result = {};
  Object.keys(obj1).forEach((key) => {
    result[key] = obj1[key];
  });
  Object.keys(obj2).forEach((key) => {
    result[key] = obj2[key];
  });
  return result;
}

function fail(error) {
  logToConsole('Enrich from Calendly API: ' + error);
  return undefined;
}

// Trims and lowercases the email address, as expected by GA4 user-provided
// data and the conversion APIs. Returns undefined when there is nothing usable.
function normalizeEmail(value) {
  if (getType(value) !== 'string') {
    return undefined;
  }

  const email = value.trim().toLowerCase();

  if (!email || email.indexOf('@') < 1) {
    return undefined;
  }

  return email;
}

// Copies the payment data onto the payload. The nested object is kept for
// reference, minus the "terms" field which is the same long text on every
// booking, and the fields a conversion tag needs are flattened to the top
// level: transaction_id (the provider charge id, usable for deduplication),
// value, currency and payment_successful.
function addPaymentData(payload, payment) {
  const details = {};

  Object.keys(payment).forEach((key) => {
    if (key !== 'terms' && payment[key] !== null) {
      details[key] = payment[key];
    }
  });

  if (Object.keys(details).length > 0) {
    payload.payment = details;
  }

  if (payment.external_id) {
    payload.transaction_id = payment.external_id;
  }

  if (getType(payment.amount) === 'number') {
    payload.value = payment.amount;
  }

  if (payment.currency) {
    payload.currency = payment.currency;
  }

  if (getType(payment.successful) === 'boolean') {
    payload.payment_successful = payment.successful;
  }
}

// Builds a { question text: answer } map out of a questions_and_answers array.
// Empty answers are skipped, and when a routing form asks the same question
// twice (branching), the first non-empty answer wins.
function buildAnswerMap(questionsAndAnswers) {
  const map = {};

  if (!questionsAndAnswers) {
    return map;
  }

  questionsAndAnswers.forEach((q_and_a) => {
    if (getType(q_and_a.question) !== 'string') {
      return;
    }

    const question = q_and_a.question.trim();
    const answer = getType(q_and_a.answer) === 'string' ? q_and_a.answer.trim() : q_and_a.answer;

    if (!question || !answer) {
      return;
    }

    if (map[question] === undefined) {
      map[question] = answer;
    }
  });

  return map;
}

/*
 * Payload builders
 */

function buildEventPayload(event) {
  const payload = {};

  if (!event) {
    return payload;
  }

  if (event.name) {
    payload.name = event.name;
  }

  if (event.meeting_notes_plain) {
    payload.meeting_notes_plain = event.meeting_notes_plain;
  }

  if (event.event_guests && event.event_guests.length > 0) {
    payload.event_guests = event.event_guests;
  }

  if (event.invitees_counter) {
    payload.invitees_counter = event.invitees_counter;
  }

  if (event.start_time) {
    payload.start_time = event.start_time;
  }

  if (event.end_time) {
    payload.end_time = event.end_time;
  }

  // Prefixed so they do not collide with the invitee timestamps on merge.
  if (event.created_at) {
    payload.event_created_at = event.created_at;
  }

  if (event.updated_at) {
    payload.event_updated_at = event.updated_at;
  }

  if (event.location) {
    payload.location = event.location;
  }

  return payload;
}

function buildTrackingPayload(invitee) {
  const payload = {};

  if (!invitee || !invitee.tracking) {
    return payload;
  }

  const keys = ['utm_campaign', 'utm_source', 'utm_medium', 'utm_content', 'utm_term', 'salesforce_uuid'];

  keys.forEach((key) => {
    if (invitee.tracking[key]) {
      payload[key] = invitee.tracking[key];
    }
  });

  return payload;
}

function buildRoutingFormPayload(submission) {
  const payload = {};

  if (!submission || !submission.questions_and_answers) {
    return payload;
  }

  payload.routing_form_questions = [];
  payload.routing_form_answers = [];

  submission.questions_and_answers.forEach((q_and_a) => {
    payload.routing_form_questions.push(q_and_a.question);
    payload.routing_form_answers.push(q_and_a.answer);
  });

  const answerMap = buildAnswerMap(submission.questions_and_answers);
  if (Object.keys(answerMap).length > 0) {
    payload.routing_form_answers_by_question = answerMap;
  }

  return payload;
}

function buildInviteePayload(invitee) {
  const payload = {};

  if (!invitee) {
    return payload;
  }

  if (invitee.timezone) {
    payload.timezone = invitee.timezone;
  }

  if (invitee.payment) {
    addPaymentData(payload, invitee.payment);
  }

  if (invitee.scheduling_method) {
    payload.scheduling_method = invitee.scheduling_method;
  }

  if (invitee.created_at) {
    payload.created_at = invitee.created_at;
  }

  if (invitee.updated_at) {
    payload.updated_at = invitee.updated_at;
  }

  const userData = {};
  const address = {};

  const emailAddress = normalizeEmail(invitee.email);
  if (emailAddress) {
    userData.email_address = emailAddress;
  }

  if (invitee.questions_and_answers && invitee.questions_and_answers.length > 0) {
    payload.event_questions = [];
    payload.event_answers = [];

    invitee.questions_and_answers.forEach((q_and_a) => {
      payload.event_questions.push(q_and_a.question);
      payload.event_answers.push(q_and_a.answer);

      if (!userData.phone_number) {
        const phoneNumber = toPhoneNumber(q_and_a.answer, true);
        if (phoneNumber) {
          userData.phone_number = phoneNumber;
        }
      }
    });

    const answerMap = buildAnswerMap(invitee.questions_and_answers);
    if (Object.keys(answerMap).length > 0) {
      payload.event_answers_by_question = answerMap;
    }
  }

  // The SMS reminder number is more reliable than a free-text answer.
  if (invitee.text_reminder_number) {
    const reminderNumber = toPhoneNumber(invitee.text_reminder_number, false);
    if (reminderNumber) {
      userData.phone_number = reminderNumber;
    }
  }

  if (invitee.name) {
    const nameParts = [];
    invitee.name.split(' ').forEach((part) => {
      if (part) {
        nameParts.push(part);
      }
    });

    if (nameParts.length > 0) {
      address.first_name = nameParts[0];

      let lastName = '';
      nameParts.forEach((part, index) => {
        if (index > 0) {
          lastName = lastName ? lastName + ' ' + part : part;
        }
      });

      if (lastName) {
        address.last_name = lastName;
      }
    }
  }

  // Explicit fields win over the ones parsed from the full name.
  if (invitee.first_name) {
    address.first_name = invitee.first_name;
  }

  if (invitee.last_name) {
    address.last_name = invitee.last_name;
  }

  if (Object.keys(address).length > 0) {
    userData.address = address;
  }

  if (Object.keys(userData).length > 0) {
    payload.user_data = userData;
  }

  const tracking = buildTrackingPayload(invitee);
  if (Object.keys(tracking).length > 0) {
    payload.tracking = tracking;
  }

  return payload;
}

/*
 * Main
 */

const inviteeUri = data.inviteeUri;

if (getType(inviteeUri) !== 'string' ||
    inviteeUri.indexOf(EVENTS_ENDPOINT) !== 0 ||
    inviteeUri.indexOf('/invitees/') === -1) {
  return fail('"' + inviteeUri + '" is not a valid Calendly invitee URI.');
}

const eventUri = getEventUri(inviteeUri);

return Promise.all([
  eventUri ? callCalendly(eventUri) : resolved(undefined),
  callCalendly(inviteeUri)
]).then((results) => {
  const invitee = results[1];

  // The invitee is the mandatory part: without it there is nothing to return.
  // The event details, on the other hand, are a bonus.
  if (!invitee) {
    return undefined;
  }

  const payload = mergeObjects(buildEventPayload(results[0]), buildInviteePayload(invitee));

  if (!invitee.routing_form_submission) {
    return payload;
  }

  // The routing form is a bonus too: if the call fails, return the rest.
  return callCalendly(invitee.routing_form_submission).then((submission) => {
    return submission ? mergeObjects(payload, buildRoutingFormPayload(submission)) : payload;
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
                "string": "https://api.calendly.com/scheduled_events/*"
              },
              {
                "type": 1,
                "string": "https://api.calendly.com/routing_form_submissions/*"
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
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  }
]


___TESTS___

scenarios:
- name: Returns the event data merged with the invitee data
  code: |-
    const resources = {};
    resources[EVENT_URI] = baseEvent();
    resources[INVITEE_URI] = baseInvitee();
    mockCalendly(resources);

    runCode(mockData).then((result) => {
      assertThat(result.name).isEqualTo('30 Minute Meeting');
      assertThat(result.start_time).isEqualTo('2026-08-31T07:00:00Z');
      assertThat(result.timezone).isEqualTo('Europe/Berlin');
      assertThat(result.user_data.email_address).isEqualTo('training@data-marketing-school.com');
      assertThat(result.event_questions).isEqualTo(['How did you hear about us?']);
      assertThat(result.event_answers).isEqualTo(['A newsletter']);
    });
- name: Keeps the event timestamps separate from the invitee timestamps
  code: |-
    const resources = {};
    resources[EVENT_URI] = baseEvent();
    resources[INVITEE_URI] = baseInvitee();
    mockCalendly(resources);

    runCode(mockData).then((result) => {
      assertThat(result.event_created_at).isEqualTo('2026-08-29T15:49:46.781730Z');
      assertThat(result.created_at).isEqualTo('2026-08-29T15:49:46.805208Z');
    });
- name: Keeps every word of a composed last name
  code: |-
    const invitee = baseInvitee();
    invitee.name = 'Jean-Pierre de la Fontaine';

    const resources = {};
    resources[EVENT_URI] = baseEvent();
    resources[INVITEE_URI] = invitee;
    mockCalendly(resources);

    runCode(mockData).then((result) => {
      assertThat(result.user_data.address.first_name).isEqualTo('Jean-Pierre');
      assertThat(result.user_data.address.last_name).isEqualTo('de la Fontaine');
    });
- name: Prefers the dedicated first name and last name fields over the full name
  code: |-
    const invitee = baseInvitee();
    invitee.name = 'ignored value';
    invitee.first_name = 'Marie';
    invitee.last_name = 'Dubois';

    const resources = {};
    resources[EVENT_URI] = baseEvent();
    resources[INVITEE_URI] = invitee;
    mockCalendly(resources);

    runCode(mockData).then((result) => {
      assertThat(result.user_data.address.first_name).isEqualTo('Marie');
      assertThat(result.user_data.address.last_name).isEqualTo('Dubois');
    });
- name: Finds the phone number among the booking form answers and normalizes it
  code: |-
    const invitee = baseInvitee();
    invitee.questions_and_answers = [
      {question: 'How did you hear about us?', answer: 'A newsletter', position: 0},
      {question: 'Your phone number', answer: '+33 6 12 34 56 78', position: 1}
    ];

    const resources = {};
    resources[EVENT_URI] = baseEvent();
    resources[INVITEE_URI] = invitee;
    mockCalendly(resources);

    runCode(mockData).then((result) => {
      assertThat(result.user_data.phone_number).isEqualTo('+33612345678');
    });
- name: Does not mistake a free text answer for a phone number
  code: |-
    const invitee = baseInvitee();
    invitee.questions_and_answers = [
      {question: 'Anything else?', answer: 'We are 3 people, see you on 12/03/2026', position: 0}
    ];

    const resources = {};
    resources[EVENT_URI] = baseEvent();
    resources[INVITEE_URI] = invitee;
    mockCalendly(resources);

    runCode(mockData).then((result) => {
      assertThat(result.user_data.phone_number).isUndefined();
    });
- name: The SMS reminder number wins over the booking form answers
  code: |-
    const invitee = baseInvitee();
    invitee.questions_and_answers = [
      {question: 'Your phone number', answer: '0612345678', position: 0}
    ];
    invitee.text_reminder_number = '+33 7 98 76 54 32';

    const resources = {};
    resources[EVENT_URI] = baseEvent();
    resources[INVITEE_URI] = invitee;
    mockCalendly(resources);

    runCode(mockData).then((result) => {
      assertThat(result.user_data.phone_number).isEqualTo('+33798765432');
    });
- name: Trims and lowercases the email address
  code: |-
    const invitee = baseInvitee();
    invitee.email = '  Training@Data-Marketing-School.COM  ';

    const resources = {};
    resources[EVENT_URI] = baseEvent();
    resources[INVITEE_URI] = invitee;
    mockCalendly(resources);

    runCode(mockData).then((result) => {
      assertThat(result.user_data.email_address).isEqualTo('training@data-marketing-school.com');
    });
- name: Keeps only the tracking parameters that have a value
  code: |-
    const invitee = baseInvitee();
    invitee.tracking = {
      utm_campaign: null,
      utm_source: 'newsletter',
      utm_medium: 'email',
      utm_content: null,
      utm_term: null,
      salesforce_uuid: null
    };

    const resources = {};
    resources[EVENT_URI] = baseEvent();
    resources[INVITEE_URI] = invitee;
    mockCalendly(resources);

    runCode(mockData).then((result) => {
      assertThat(result.tracking).isEqualTo({utm_source: 'newsletter', utm_medium: 'email'});
    });
- name: Omits the tracking object when every parameter is empty
  code: |-
    const resources = {};
    resources[EVENT_URI] = baseEvent();
    resources[INVITEE_URI] = baseInvitee();
    mockCalendly(resources);

    runCode(mockData).then((result) => {
      assertThat(result.tracking).isUndefined();
    });
- name: Adds the routing form answers and the answer map
  code: |-
    const invitee = baseInvitee();
    invitee.routing_form_submission = ROUTING_FORM_URI;

    const resources = {};
    resources[EVENT_URI] = baseEvent();
    resources[INVITEE_URI] = invitee;
    resources[ROUTING_FORM_URI] = baseSubmission();
    mockCalendly(resources);

    runCode(mockData).then((result) => {
      assertThat(result.routing_form_questions).isEqualTo(['What is your name?', 'What do you like?']);
      assertThat(result.routing_form_answers).isEqualTo(['Marie', 'Work']);
      assertThat(result.routing_form_answers_by_question['What do you like?']).isEqualTo('Work');
    });
- name: Skips the blank answers in the answer map
  code: |-
    const invitee = baseInvitee();
    invitee.routing_form_submission = ROUTING_FORM_URI;

    const submission = baseSubmission();
    submission.questions_and_answers = [
      {question: 'Budget?', answer: ''},
      {question: 'Budget?', answer: '50k'}
    ];

    const resources = {};
    resources[EVENT_URI] = baseEvent();
    resources[INVITEE_URI] = invitee;
    resources[ROUTING_FORM_URI] = submission;
    mockCalendly(resources);

    runCode(mockData).then((result) => {
      assertThat(result.routing_form_answers_by_question).isEqualTo({'Budget?': '50k'});
    });
- name: Still returns the other data when the routing form call fails
  code: |-
    const invitee = baseInvitee();
    invitee.routing_form_submission = ROUTING_FORM_URI;

    const resources = {};
    resources[EVENT_URI] = baseEvent();
    resources[INVITEE_URI] = invitee;
    mockCalendly(resources);

    runCode(mockData).then((result) => {
      assertThat(result.name).isEqualTo('30 Minute Meeting');
      assertThat(result.user_data.email_address).isEqualTo('training@data-marketing-school.com');
      assertThat(result.routing_form_questions).isUndefined();
    });
- name: Flattens the payment data and removes the payment terms
  code: |-
    const invitee = baseInvitee();
    invitee.payment = {
      external_id: 'ch_3Q7xKjL2eZvKYlo2',
      provider: 'stripe',
      amount: 150,
      currency: 'EUR',
      terms: 'Full refund if cancelled 24 hours in advance.',
      successful: true
    };

    const resources = {};
    resources[EVENT_URI] = baseEvent();
    resources[INVITEE_URI] = invitee;
    mockCalendly(resources);

    runCode(mockData).then((result) => {
      assertThat(result.transaction_id).isEqualTo('ch_3Q7xKjL2eZvKYlo2');
      assertThat(result.value).isEqualTo(150);
      assertThat(result.currency).isEqualTo('EUR');
      assertThat(result.payment_successful).isEqualTo(true);
      assertThat(result.payment.terms).isUndefined();
    });
- name: Keeps a zero amount and an unsuccessful payment
  code: |-
    const invitee = baseInvitee();
    invitee.payment = {
      external_id: 'ch_free',
      provider: 'stripe',
      amount: 0,
      currency: 'EUR',
      terms: null,
      successful: false
    };

    const resources = {};
    resources[EVENT_URI] = baseEvent();
    resources[INVITEE_URI] = invitee;
    mockCalendly(resources);

    runCode(mockData).then((result) => {
      assertThat(result.value).isEqualTo(0);
      assertThat(result.payment_successful).isEqualTo(false);
    });
- name: Omits the payment keys when the meeting is free
  code: |-
    const resources = {};
    resources[EVENT_URI] = baseEvent();
    resources[INVITEE_URI] = baseInvitee();
    mockCalendly(resources);

    runCode(mockData).then((result) => {
      assertThat(result.payment).isUndefined();
      assertThat(result.transaction_id).isUndefined();
      assertThat(result.value).isUndefined();
    });
- name: Calls the two endpoints with the access token
  code: |-
    const resources = {};
    resources[EVENT_URI] = baseEvent();
    resources[INVITEE_URI] = baseInvitee();
    mockCalendly(resources);

    runCode(mockData).then(() => {
      assertThat(requestedUrls).isEqualTo([EVENT_URI, INVITEE_URI]);
      assertThat(requestedHeaders[0].Authorization).isEqualTo('Bearer test-token');
    });
- name: Returns undefined for an invalid invitee URI without calling the API
  code: |-
    mockCalendly({});

    const result = runCode({
      personalAccessToken: 'test-token',
      inviteeUri: 'https://api.calendly.com/scheduled_events/26623b77'
    });

    assertThat(result).isUndefined();
    assertApi('sendHttpRequest').wasNotCalled();
- name: Returns undefined when the invitee URI is empty
  code: |-
    mockCalendly({});

    const result = runCode({personalAccessToken: 'test-token', inviteeUri: undefined});

    assertThat(result).isUndefined();
    assertApi('sendHttpRequest').wasNotCalled();
- name: Still returns the invitee data when the event call fails
  code: |-
    const resources = {};
    resources[INVITEE_URI] = baseInvitee();
    mockCalendly(resources);

    runCode(mockData).then((result) => {
      assertThat(result.user_data.email_address).isEqualTo('training@data-marketing-school.com');
      assertThat(result.timezone).isEqualTo('Europe/Berlin');
      assertThat(result.name).isUndefined();
    });
- name: Returns undefined when the invitee call answers with an error
  code: |-
    const resources = {};
    resources[EVENT_URI] = baseEvent();
    mockCalendly(resources);

    runCode(mockData).then((result) => {
      assertThat(result).isUndefined();
    });
setup: |-
  const JSON = require('JSON');
  const Promise = require('Promise');

  const EVENT_URI = 'https://api.calendly.com/scheduled_events/26623b77-3e93-457a-a88f-61e7e81d70c8';
  const INVITEE_URI = EVENT_URI + '/invitees/120b9716-27ff-4244-a01b-f178213b8955';
  const ROUTING_FORM_URI = 'https://api.calendly.com/routing_form_submissions/291314f7-a067-43e0-95e7-5ebcd1f4b1c8';

  const mockData = {
    personalAccessToken: 'test-token',
    inviteeUri: INVITEE_URI
  };

  let requestedUrls = [];
  let requestedHeaders = [];

  // Answers with the resource registered for the requested URL, or with a 404
  // when the URL is not in the map.
  function mockCalendly(resources) {
    requestedUrls = [];
    requestedHeaders = [];

    mock('sendHttpRequest', (url, options) => {
      requestedUrls.push(url);
      requestedHeaders.push(options.headers);

      return Promise.create((resolve) => {
        if (resources[url]) {
          resolve({statusCode: 200, body: JSON.stringify({resource: resources[url]})});
        } else {
          resolve({statusCode: 404, body: JSON.stringify({message: 'Resource not found'})});
        }
      });
    });
  }

  function baseEvent() {
    return {
      name: '30 Minute Meeting',
      meeting_notes_plain: null,
      status: 'active',
      start_time: '2026-08-31T07:00:00Z',
      end_time: '2026-08-31T07:30:00Z',
      location: {type: 'google_conference', status: 'pushed', join_url: 'https://calendly.com/events/26623b77/google_meet'},
      invitees_counter: {total: 1, active: 1, limit: 1},
      created_at: '2026-08-29T15:49:46.781730Z',
      updated_at: '2026-08-29T15:49:50.106776Z',
      event_guests: []
    };
  }

  function baseInvitee() {
    return {
      email: 'training@data-marketing-school.com',
      first_name: null,
      last_name: null,
      name: 'Marie Dubois',
      status: 'active',
      questions_and_answers: [
        {question: 'How did you hear about us?', answer: 'A newsletter', position: 0}
      ],
      timezone: 'Europe/Berlin',
      created_at: '2026-08-29T15:49:46.805208Z',
      updated_at: '2026-08-29T15:49:46.805208Z',
      tracking: {
        utm_campaign: null,
        utm_source: null,
        utm_medium: null,
        utm_content: null,
        utm_term: null,
        salesforce_uuid: null
      },
      text_reminder_number: null,
      routing_form_submission: null,
      payment: null,
      scheduling_method: null
    };
  }

  function baseSubmission() {
    return {
      questions_and_answers: [
        {question_uuid: 'e15b84ae-5974-43db-a7c2-1dc793335665', question: 'What is your name?', answer: 'Marie'},
        {question_uuid: '1a3c2f2e-7b46-4f05-8f94-54ce6d5c4b17', question: 'What do you like?', answer: 'Work'}
      ],
      tracking: {utm_source: null},
      submitter_type: 'Invitee'
    };
  }


___NOTES___

Created on 31/12/2025, 17:10:01


