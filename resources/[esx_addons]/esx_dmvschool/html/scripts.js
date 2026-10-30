// question variables
var questionNumber = 1;
var userAnswer = [];
var goodAnswer = [];
var questionUsed = [];
var nbQuestionToAnswer = 10; // don't forget to change the progress bar max value in html
var nbAnswerNeeded = 5; // out of nbQuestionToAnswer
var nbPossibleQuestions = tableauQuestion.length; // number of questions in database questions.js
var lastClick = 0;

function nuiPost(callback, data) {
	const resource = (typeof GetParentResourceName === 'function') ? GetParentResourceName() : 'esx_dmvschool';
	return fetch(`https://${resource}/${callback}`, {
		method: 'POST',
		headers: { 'Content-Type': 'application/json; charset=UTF-8' },
		body: JSON.stringify(data || {})
	}).then(function (response) {
		return response.text();
	}).catch(function (error) {
		console.log('[esx_dmvschool] NUI post failed:', callback, error);
	});
}


function getRandomQuestion() {
	var random = Math.floor(Math.random() * nbPossibleQuestions);

	while (true) {
		if (questionUsed.indexOf(random) === -1) {
			break;
		}

		random = Math.floor(Math.random() * nbPossibleQuestions);
	}

	questionUsed.push(random);

	return random;
}

// Partial Functions
function closeMain() {
	$(".home").css("display", "none");
}
function openMain() {
	$(".home").css("display", "block");
}
function closeAll() {
	$(".body").css("display", "none");
}
function openQuestionnaire() {
	$(".questionnaire-container").css("display", "block");
	var randomQuestion = getRandomQuestion();

	$("#questionNumero").html("Spørgsmål: " + questionNumber);
	$("#question").html(tableauQuestion[randomQuestion].question);
	$(".answerA").html(tableauQuestion[randomQuestion].propositionA);
	$(".answerB").html(tableauQuestion[randomQuestion].propositionB);
	$(".answerC").html(tableauQuestion[randomQuestion].propositionC);
	$(".answerD").html(tableauQuestion[randomQuestion].propositionD);
	$('input[name=question]').attr('checked', false);

	goodAnswer.push(tableauQuestion[randomQuestion].reponse);
	$(".questionnaire-container .progression").val(questionNumber - 1);
}
function openResultGood() {
	$(".resultGood").css("display", "block");
}
function openResultBad() {
	$(".resultBad").css("display", "block");
}
function openContainer() {
	$(".question-container").css("display", "block");
}
function closeContainer() {
	$(".question-container").css("display", "none");
}

// Listen for NUI Events
window.addEventListener('message', function (event) {
	var item = event.data;

	// Open & Close main window
	if (item.openQuestion == true) {
		openContainer();
		openMain();
	}

	if (item.openQuestion == false) {
		closeContainer();
		closeMain();
	}

	// Open sub-windows / partials
	if (item.openSection == "question") {
		closeAll();
		openQuestionnaire();
	}
});

// Handle Button Presses
$(".btnQuestion").click(function () {
	nuiPost('question');
});

$(".btnClose").click(function () {
	nuiPost('close');
	userAnswer = [];
	goodAnswer = [];
	questionUsed = [];
	questionNumber = 1;
});

$(".btnKick").click(function () {
	nuiPost('kick');
	userAnswer = [];
	goodAnswer = [];
	questionUsed = [];
	questionNumber = 1;
});

// Handle Form Submits
$("#question-form").submit(function (e) {
	e.preventDefault();

	if (questionNumber != nbQuestionToAnswer) {
		//question 1 to 9: pushing answer in array
		closeAll();
		userAnswer.push($('input[name="question"]:checked').val());
		questionNumber++;
		openQuestionnaire();
	} else {
		// question 10: comparing arrays and sending number of good answers
		userAnswer.push($('input[name="question"]:checked').val());
		var nbGoodAnswer = 0;
		for (i = 0; i < nbQuestionToAnswer; i++) {
			if (userAnswer[i] == goodAnswer[i]) {
				nbGoodAnswer++;
			}
		}

		closeAll();
		if (nbGoodAnswer >= nbAnswerNeeded) {
			openResultGood();
		} else {
			openResultBad();
		}
	}

	return false;
});


// =========================
// Custom DMV School UI
// =========================
let selectedSchoolItem = null;
let schoolItems = [];

const iconMap = {
	car: 'car',
	bike: 'bike',
	truck: 'truck',
	'book-open': 'book-open'
};

function moneyFormat(value) {
	return '$' + Number(value || 0).toLocaleString('en-US');
}

function setIcon(el, icon) {
	el.setAttribute('data-icon', iconMap[icon] || 'car');
}

function closeSchoolUi() {
	$('#school-app').addClass('school-hidden');
	$('#school-confirm').addClass('school-hidden');
	selectedSchoolItem = null;
}

function openSchoolUi(data) {
	schoolItems = data.categories || [];
	const theoryPassed = data.theoryPassed === true;
	const grid = $('#school-grid');
	grid.empty();

	$('#school-app').removeClass('school-hidden');
	$('#school-confirm').addClass('school-hidden');
	$('#school-subtitle').text(theoryPassed ? 'Vælg hvilken type kørekort du vil tage.' : 'Tag din teoriprøve for at få adgang til kørekort kategorier.');
	$('#school-status .status-title').text(theoryPassed ? 'EFTER TEORI' : 'FØR TEORI');
	$('#school-status .status-text').text(theoryPassed ? 'Alle kategorier er nu tilgængelige' : 'Kun teoriprøve er tilgængelig');

	schoolItems.forEach((item, index) => {
		const card = $('<div class="school-card"></div>');
		if (item.completed) card.addClass('completed');

		const icon = $('<div class="card-icon"></div>');
		setIcon(icon[0], item.icon);

		card.append(icon);
		card.append($('<h2></h2>').text(item.title));
		card.append('<div class="card-line"></div>');
		card.append($('<p></p>').text(item.description));

		if (item.completed) {
			card.append('<button class="completed-button" type="button">Bestået ✓</button>');
		} else {
			const button = $('<button class="price-button" type="button"></button>');
			button.text('Vælg • ' + moneyFormat(item.price));
			button.on('click', function () {
				selectedSchoolItem = item;
				$('#confirm-title').text(item.title);
				$('#confirm-price').text(moneyFormat(item.price));
				setIcon(document.getElementById('confirm-icon'), item.icon);
				$('#school-confirm').removeClass('school-hidden');
			});
			card.append(button);
		}

		grid.append(card);
	});
}

window.addEventListener('message', function (event) {
	const item = event.data;
	if (item.action === 'openSchool') openSchoolUi(item);
	if (item.action === 'closeSchool') closeSchoolUi();
	if (item.action === 'schoolPaymentFailed') { $('#school-confirm').addClass('school-hidden'); $('#confirm-yes').prop('disabled', false).text('✓ Bekræft'); }
});

$('#school-close').click(function () {
	nuiPost('schoolClose');
});

$('#confirm-x, #confirm-cancel').click(function () {
	$('#school-confirm').addClass('school-hidden');
	selectedSchoolItem = null;
});

$('#confirm-yes').click(function () {
	if (!selectedSchoolItem) return;
	const payload = {
		id: selectedSchoolItem.id,
		type: selectedSchoolItem.type,
		price: selectedSchoolItem.price
	};
	$('#confirm-yes').prop('disabled', true).text('Starter...');
	nuiPost('confirmPurchase', payload).finally(function () {
		setTimeout(function () {
			$('#confirm-yes').prop('disabled', false).text('✓ Bekræft');
		}, 800);
	});
});

$(document).keyup(function (e) {
	if (e.key === 'Escape') {
		if (!$('#school-app').hasClass('school-hidden')) {
			nuiPost('schoolClose');
		}
	}
});
