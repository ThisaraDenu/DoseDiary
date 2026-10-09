import 'package:flutter/material.dart';

const localizedText = <String, Map<String, String>>{
  'si': {
    'Home': 'මුල් පිටුව',
    'Medications': 'ඖෂධ',
    'History': 'ඉතිහාසය',
    'Settings': 'සැකසුම්',
    'Taken': 'ලබා ගත්තා',
    'Missed': 'මඟ හැරුණා',
    'Skipped': 'මඟ හැරියා',
    'Pending': 'බලාපොරොත්තුවෙන්',
    'Overdue': 'කල් ඉකුත්',
    'Snoozed': 'පසුවට තැබූ',
    'Accessibility': 'ප්‍රවේශ්‍යතාව',
    'Text Size': 'අකුරු ප්‍රමාණය',
    'App Colour': 'යෙදුමේ වර්ණය',
    'Choose a comfortable colour for controls across the app.':
        'යෙදුම පුරා පාලන සඳහා ඔබට පහසු වර්ණයක් තෝරන්න.',
    'Every choice uses high-contrast text. Labels and icons remain visible, so colour is not the only signal.':
        'සෑම තේරීමක්ම පැහැදිලි පෙළ භාවිත කරයි. වර්ණයට අමතරව ලේබල් සහ අයිකන ද පෙන්වයි.',
    'Smaller': 'කුඩා',
    'Larger': 'විශාල',
    'Simpler Language': 'සරල භාෂාව',
    'Use shorter, plainer words throughout the app.':
        'යෙදුම පුරා කෙටි සහ සරල වචන භාවිත කරන්න.',
    'Language': 'භාෂාව',
    'Selected': 'තෝරා ඇත',
    'Crimson': 'තද රතු',
    'Ocean Blue': 'සාගර නිල්',
    'Teal': 'තේල්',
    'Violet': 'දම්',
    'High Contrast': 'ඉහළ ප්‍රතිවිරුද්ධතාව',
    'DoseDiary classic': 'DoseDiary සාම්ප්‍රදායික',
    'Clear and calm': 'පැහැදිලි සහ සන්සුන්',
    'Colour-vision friendly': 'වර්ණ දෘෂ්ටියට හිතකර',
    'Distinct and balanced': 'පැහැදිලි සහ සමබර',
    'Strongest definition': 'ඉතා පැහැදිලි',
    'Normal': 'සාමාන්‍ය',
    'Small': 'කුඩා',
    'Large': 'විශාල',
    'Extra Large': 'ඉතා විශාල',
    'Largest': 'විශාලතම',
    'Patient Mode': 'රෝගී ප්‍රකාරය',
    'Caregiver Mode': 'භාරකරු ප්‍රකාරය',
    'ACTIVE VIEW': 'සක්‍රිය දසුන',
    'Stay healthy, stay on track.': 'සෞඛ්‍ය සම්පන්නව, නියමිත මඟෙහි සිටින්න.',
    'NEXT MEDICATION': 'මීළඟ ඖෂධය',
    'NEXT MEDICATION SOON': 'මීළඟ ඖෂධය ළඟදීම',
    'Today’s doses': 'අද මාත්‍රා',
    'Medication & Today’s Schedule': 'ඖෂධ සහ අද කාලසටහන',
    'Weekly Adherence': 'සතිපතා අනුගමනය',
    'Adherence': 'අනුගමනය',
    'Refills': 'නැවත පිරවීම්',
    'Scheduled': 'කාලසටහන්ගත',
    'See All': 'සියල්ල බලන්න',
    'View Medications': 'ඖෂධ බලන්න',
    'Add Medication': 'ඖෂධයක් එක් කරන්න',
    'No medications scheduled for today': 'අදට ඖෂධ කාලසටහන්ගත කර නැත',
    'You are all caught up': 'ඔබ සියල්ල සම්පූර්ණ කර ඇත',
    'My Caregivers': 'මගේ භාරකරුවන්',
    'Add Caregiver': 'භාරකරුවෙකු එක් කරන්න',
    'No Caregivers Added': 'භාරකරුවන් එක් කර නැත',
    'Add First Caregiver': 'පළමු භාරකරු එක් කරන්න',
    'Remove Caregiver': 'භාරකරු ඉවත් කරන්න',
    'Add Patient': 'රෝගියෙකු එක් කරන්න',
    'No Patient Allocated': 'රෝගියෙකු වෙන් කර නැත',
    'Allocate Patient': 'රෝගියෙකු වෙන් කරන්න',
    'Remove Patient': 'රෝගියා ඉවත් කරන්න',
    'Relationship': 'සම්බන්ධතාව',
    'Email': 'ඊමේල්',
    'Phone': 'දුරකථනය',
    'Gender': 'ස්ත්‍රී පුරුෂ භාවය',
    'Location': 'ස්ථානය',
    'Phone Number (Optional)': 'දුරකථන අංකය (විකල්ප)',
    'Cancel': 'අවලංගු කරන්න',
    'Remove': 'ඉවත් කරන්න',
    'Other': 'වෙනත්',
    'Close': 'වසන්න',
    'Details': 'විස්තර',
    'Updated': 'යාවත්කාලීනයි',
    'View Log': 'වාර්තාව බලන්න',
    'View only': 'බැලීමට පමණි',
    'Active medications': 'සක්‍රිය ඖෂධ',
    'Medication details': 'ඖෂධ විස්තර',
    'Mark as Taken': 'ලබා ගත් ලෙස සලකුණු කරන්න',
    'Send Gentle Ping': 'මෘදු මතක් කිරීමක් යවන්න',
    'Notify Patient to Refill': 'නැවත පිරවීමට රෝගියාට දන්වන්න',
    'Refill': 'නැවත පිරවීම',
    'Later': 'පසුව',
    'Notifications': 'දැනුම්දීම්',
    'Privacy': 'පෞද්ගලිකත්වය',
    'Help & Support': 'උදව් සහ සහාය',
    'Data Storage': 'දත්ත ගබඩාව',
    'Medical Safety Notice': 'වෛද්‍ය ආරක්ෂක නිවේදනය',
    'Important Notice': 'වැදගත් නිවේදනය',
    'Medication & Tracking': 'ඖෂධ සහ නිරීක්ෂණය',
    'My medications': 'මගේ ඖෂධ',
    'Medication history': 'ඖෂධ ඉතිහාසය',
    'Adherence insights': 'ඖෂධ අනුගමන තොරතුරු',
    'Refills & stock': 'නැවත පිරවීම් සහ තොග',
    'Care Network': 'සත්කාර ජාලය',
    'Caregivers & patients': 'භාරකරුවන් සහ රෝගීන්',
    'Notification centre': 'දැනුම්දීම් මධ්‍යස්ථානය',
    'Preferences': 'අභිරුචි',
    'Reminders & notifications': 'මතක් කිරීම් සහ දැනුම්දීම්',
    'Accessibility & language': 'ප්‍රවේශ්‍යතාව සහ භාෂාව',
    'App permissions': 'යෙදුම් අවසර',
    'Data & Security': 'දත්ත සහ ආරක්ෂාව',
    'Profile & account': 'පැතිකඩ සහ ගිණුම',
    'Data & sync': 'දත්ත සහ සමමුහුර්ත කිරීම',
    'Security & permissions': 'ආරක්ෂාව සහ අවසර',
    'Help & Information': 'උදව් සහ තොරතුරු',
    'Help & support': 'උදව් සහ සහාය',
    'About DoseDiary': 'DoseDiary ගැන',
    'Session': 'සැසිය',
    'Sign out': 'පිටවන්න',
    'Dose schedule': 'මාත්‍රා කාලසටහන',
    'Error loading schedule': 'කාලසටහන පූරණය කළ නොහැක',
    'Medication History': 'ඖෂධ ඉතිහාසය',
    'Weekly Dose Summary': 'සතිපතා මාත්‍රා සාරාංශය',
    'Selected Period': 'තෝරාගත් කාලසීමාව',
    'Status Key Reference': 'තත්ත්ව සංකේත විස්තරය',
    'Get history as PDF': 'ඉතිහාසය PDF ලෙස ලබාගන්න',
    'Download daily history PDF': 'දෛනික ඉතිහාස PDF බාගන්න',
    'Download weekly history PDF': 'සතිපතා ඉතිහාස PDF බාගන්න',
    'Try again': 'නැවත උත්සාහ කරන්න',
    'Preview text': 'පෙරදසුන් පෙළ',
    'Add Another Caregiver': 'තවත් භාරකරුවෙකු එක් කරන්න',
    'Add Another Patient': 'තවත් රෝගියෙකු එක් කරන්න',
    'Add Your First Medication': 'ඔබේ පළමු ඖෂධය එක් කරන්න',
    'All': 'සියල්ල',
    'Answers to common DoseDiary questions':
        'සාමාන්‍ය DoseDiary ප්‍රශ්නවලට පිළිතුරු',
    'Caregiver / Carer': 'භාරකරු',
    'Caregiver account': 'භාරකරු ගිණුම',
    'Caregiver Full Name *': 'භාරකරුගේ සම්පූර්ණ නම *',
    'Child / Dependent': 'දරුවා / යැපෙන්නා',
    'Clear read notifications': 'කියවූ දැනුම්දීම් ඉවත් කරන්න',
    'Cloud sync, local records, and PDF exports':
        'ක්ලවුඩ් සමමුහුර්තය, දේශීය වාර්තා සහ PDF අපනයන',
    'Confirmed on Smart Cap': 'Smart Cap මඟින් තහවුරුයි',
    'Could not load medication history': 'ඖෂධ ඉතිහාසය පූරණය කළ නොහැක',
    'Could not save the history PDF. Try again.':
        'ඉතිහාස PDF සුරැකීමට නොහැකි විය. නැවත උත්සාහ කරන්න.',
    'Creating medication history PDF...': 'ඖෂධ ඉතිහාස PDF සාදමින්...',
    'Daughter': 'දියණිය',
    'Delete': 'මකන්න',
    'Doctor / Physician': 'වෛද්‍යවරයා',
    'DoseDiary ID copied': 'DoseDiary ID පිටපත් කළා',
    'Family Member': 'පවුලේ සාමාජිකයා',
    'Father': 'පියා',
    'Grandparent': 'ආච්චි / සීයා',
    'ID unavailable': 'ID ලබාගත නොහැක',
    'Important information about using this app':
        'මෙම යෙදුම භාවිත කිරීම පිළිබඳ වැදගත් තොරතුරු',
    'Inventory levels and refill reminders':
        'තොග මට්ටම් සහ නැවත පිරවීමේ මතක් කිරීම්',
    'Manage device access used by DoseDiary':
        'DoseDiary භාවිත කරන උපාංග ප්‍රවේශය කළමනාකරණය කරන්න',
    'Mark all read': 'සියල්ල කියවූ ලෙස සලකුණු කරන්න',
    'Medication history PDF downloaded successfully.':
        'ඖෂධ ඉතිහාස PDF සාර්ථකව බාගත විය.',
    'Mother': 'මව',
    'NEW': 'නව',
    'No active medications are available to view.': 'බැලීමට සක්‍රිය ඖෂධ නොමැත.',
    'No Medications Added Yet': 'තවම ඖෂධ එක් කර නැත',
    'No Regimen Scheduled for Today': 'අදට ඖෂධ ක්‍රමයක් කාලසටහන්ගත කර නැත',
    'Notification previews and data storage':
        'දැනුම්දීම් පෙරදසුන් සහ දත්ත ගබඩාව',
    'Nurse / Home Care': 'හෙද / නිවාස සත්කාර',
    'Password, device access, and preference reset':
        'මුරපදය, උපාංග ප්‍රවේශය සහ අභිරුචි යළි පිහිටුවීම',
    'Patient / Client': 'රෝගියා / සේවාලාභියා',
    'Patient account': 'රෝගී ගිණුම',
    'Patient Full Name *': 'රෝගියාගේ සම්පූර්ණ නම *',
    'PDF download canceled.': 'PDF බාගැනීම අවලංගු කළා.',
    'Photo, phone, birthday, gender, and email':
        'ඡායාරූපය, දුරකථනය, උපන්දිනය, ස්ත්‍රී පුරුෂ භාවය සහ ඊමේල්',
    'Recent reminders and caregiver alerts': 'මෑත මතක් කිරීම් සහ භාරකරු ඇඟවීම්',
    'Retry & Grace Period': 'නැවත උත්සාහ සහ සහන කාලය',
    'Review medication-taking patterns': 'ඖෂධ ලබාගැනීමේ රටා සමාලෝචනය කරන්න',
    'Save & Add Caregiver': 'සුරකින්න සහ භාරකරු එක් කරන්න',
    'Save & Allocate Patient': 'සුරකින්න සහ රෝගියා වෙන් කරන්න',
    'Sign out of DoseDiary?': 'DoseDiary වෙතින් පිටවන්නද?',
    'Son': 'පුතා',
    'Sound, vibration, retries, and grace period':
        'ශබ්දය, කම්පනය, නැවත උත්සාහ සහ සහන කාලය',
    'Spouse': 'සහකරු / සහකාරිය',
    'Spouse / Partner': 'සහකරු / සහකාරිය',
    'Syncing patient medications…': 'රෝගියාගේ ඖෂධ සමමුහුර්ත කරමින්…',
    'Syncing today’s doses…': 'අද මාත්‍රා සමමුහුර්ත කරමින්…',
    'Text size, simpler wording, and language':
        'අකුරු ප්‍රමාණය, සරල වචන සහ භාෂාව',
    'Unread': 'නොකියවූ',
    'Version, licences, and app information':
        'අනුවාදය, බලපත්‍ර සහ යෙදුම් තොරතුරු',
    'View details': 'විස්තර බලන්න',
    'Your DoseDiary ID': 'ඔබේ DoseDiary ID',
  },
  'ta': {
    'Home': 'முகப்பு',
    'Medications': 'மருந்துகள்',
    'History': 'வரலாறு',
    'Settings': 'அமைப்புகள்',
    'Taken': 'எடுத்துக்கொண்டது',
    'Missed': 'தவறியது',
    'Skipped': 'தவிர்க்கப்பட்டது',
    'Pending': 'நிலுவையில்',
    'Overdue': 'காலதாமதம்',
    'Snoozed': 'ஒத்திவைக்கப்பட்டது',
    'Accessibility': 'அணுகல்தன்மை',
    'Text Size': 'எழுத்து அளவு',
    'App Colour': 'செயலி நிறம்',
    'Choose a comfortable colour for controls across the app.':
        'செயலி முழுவதும் உள்ள கட்டுப்பாடுகளுக்கு வசதியான நிறத்தைத் தேர்ந்தெடுக்கவும்.',
    'Every choice uses high-contrast text. Labels and icons remain visible, so colour is not the only signal.':
        'ஒவ்வொரு தேர்வும் தெளிவான உரையைப் பயன்படுத்துகிறது. நிறத்துடன் லேபிள்களும் சின்னங்களும் காட்டப்படும்.',
    'Smaller': 'சிறியது',
    'Larger': 'பெரியது',
    'Simpler Language': 'எளிய மொழி',
    'Use shorter, plainer words throughout the app.':
        'செயலி முழுவதும் குறுகிய, எளிய சொற்களைப் பயன்படுத்தவும்.',
    'Language': 'மொழி',
    'Selected': 'தேர்ந்தெடுக்கப்பட்டது',
    'Crimson': 'செந்நிறம்',
    'Ocean Blue': 'கடல் நீலம்',
    'Teal': 'நீலப்பச்சை',
    'Violet': 'ஊதா',
    'High Contrast': 'உயர் வேறுபாடு',
    'DoseDiary classic': 'DoseDiary பாரம்பரியம்',
    'Clear and calm': 'தெளிவும் அமைதியும்',
    'Colour-vision friendly': 'நிறப் பார்வைக்கு ஏற்றது',
    'Distinct and balanced': 'தனித்துவமும் சமநிலையும்',
    'Strongest definition': 'மிகத் தெளிவானது',
    'Normal': 'இயல்பு',
    'Small': 'சிறியது',
    'Large': 'பெரியது',
    'Extra Large': 'மிகப் பெரியது',
    'Largest': 'அதிகப் பெரியது',
    'Patient Mode': 'நோயாளர் முறை',
    'Caregiver Mode': 'பராமரிப்பாளர் முறை',
    'ACTIVE VIEW': 'செயலில் உள்ள காட்சி',
    'Stay healthy, stay on track.': 'ஆரோக்கியமாகவும் ஒழுங்காகவும் இருங்கள்.',
    'NEXT MEDICATION': 'அடுத்த மருந்து',
    'NEXT MEDICATION SOON': 'அடுத்த மருந்து விரைவில்',
    'Today’s doses': 'இன்றைய மருந்தளவுகள்',
    'Medication & Today’s Schedule': 'மருந்துகள் மற்றும் இன்றைய அட்டவணை',
    'Weekly Adherence': 'வாராந்திர பின்பற்றல்',
    'Adherence': 'பின்பற்றல்',
    'Refills': 'மறு நிரப்பல்கள்',
    'Scheduled': 'திட்டமிடப்பட்டது',
    'See All': 'அனைத்தையும் காண்க',
    'View Medications': 'மருந்துகளை காண்க',
    'Add Medication': 'மருந்தைச் சேர்க்கவும்',
    'No medications scheduled for today': 'இன்று மருந்துகள் திட்டமிடப்படவில்லை',
    'You are all caught up': 'அனைத்தும் முடிந்தது',
    'My Caregivers': 'என் பராமரிப்பாளர்கள்',
    'Add Caregiver': 'பராமரிப்பாளரைச் சேர்க்கவும்',
    'No Caregivers Added': 'பராமரிப்பாளர்கள் சேர்க்கப்படவில்லை',
    'Add First Caregiver': 'முதல் பராமரிப்பாளரைச் சேர்க்கவும்',
    'Remove Caregiver': 'பராமரிப்பாளரை அகற்று',
    'Add Patient': 'நோயாளரைச் சேர்க்கவும்',
    'No Patient Allocated': 'நோயாளர் ஒதுக்கப்படவில்லை',
    'Allocate Patient': 'நோயாளரை ஒதுக்கவும்',
    'Remove Patient': 'நோயாளரை அகற்று',
    'Relationship': 'உறவு',
    'Email': 'மின்னஞ்சல்',
    'Phone': 'தொலைபேசி',
    'Gender': 'பாலினம்',
    'Location': 'இடம்',
    'Phone Number (Optional)': 'தொலைபேசி எண் (விருப்பம்)',
    'Cancel': 'ரத்துசெய்',
    'Remove': 'அகற்று',
    'Other': 'மற்றவை',
    'Close': 'மூடு',
    'Details': 'விவரங்கள்',
    'Updated': 'புதுப்பிக்கப்பட்டது',
    'View Log': 'பதிவைக் காண்க',
    'View only': 'பார்வைக்கு மட்டும்',
    'Active medications': 'செயலில் உள்ள மருந்துகள்',
    'Medication details': 'மருந்து விவரங்கள்',
    'Mark as Taken': 'எடுத்ததாகக் குறிக்கவும்',
    'Send Gentle Ping': 'மென்மையான நினைவூட்டலை அனுப்பு',
    'Notify Patient to Refill': 'மறு நிரப்ப நோயாளிக்கு அறிவிக்கவும்',
    'Refill': 'மறு நிரப்பல்',
    'Later': 'பின்னர்',
    'Notifications': 'அறிவிப்புகள்',
    'Privacy': 'தனியுரிமை',
    'Help & Support': 'உதவி மற்றும் ஆதரவு',
    'Data Storage': 'தரவு சேமிப்பு',
    'Medical Safety Notice': 'மருத்துவ பாதுகாப்பு அறிவிப்பு',
    'Important Notice': 'முக்கிய அறிவிப்பு',
    'Medication & Tracking': 'மருந்துகள் மற்றும் கண்காணிப்பு',
    'My medications': 'என் மருந்துகள்',
    'Medication history': 'மருந்து வரலாறு',
    'Adherence insights': 'பின்பற்றல் விவரங்கள்',
    'Refills & stock': 'மறு நிரப்பல்கள் மற்றும் இருப்பு',
    'Care Network': 'பராமரிப்பு வலைப்பின்னல்',
    'Caregivers & patients': 'பராமரிப்பாளர்கள் மற்றும் நோயாளர்கள்',
    'Notification centre': 'அறிவிப்பு மையம்',
    'Preferences': 'விருப்பங்கள்',
    'Reminders & notifications': 'நினைவூட்டல்கள் மற்றும் அறிவிப்புகள்',
    'Accessibility & language': 'அணுகல்தன்மை மற்றும் மொழி',
    'App permissions': 'செயலி அனுமதிகள்',
    'Data & Security': 'தரவு மற்றும் பாதுகாப்பு',
    'Profile & account': 'சுயவிவரம் மற்றும் கணக்கு',
    'Data & sync': 'தரவு மற்றும் ஒத்திசைவு',
    'Security & permissions': 'பாதுகாப்பு மற்றும் அனுமதிகள்',
    'Help & Information': 'உதவி மற்றும் தகவல்',
    'Help & support': 'உதவி மற்றும் ஆதரவு',
    'About DoseDiary': 'DoseDiary பற்றி',
    'Session': 'அமர்வு',
    'Sign out': 'வெளியேறு',
    'Dose schedule': 'மருந்தளவு அட்டவணை',
    'Error loading schedule': 'அட்டவணையை ஏற்ற முடியவில்லை',
    'Medication History': 'மருந்து வரலாறு',
    'Weekly Dose Summary': 'வாராந்திர மருந்தளவு சுருக்கம்',
    'Selected Period': 'தேர்ந்தெடுத்த காலம்',
    'Status Key Reference': 'நிலை குறியீட்டு விளக்கம்',
    'Get history as PDF': 'வரலாற்றை PDF ஆகப் பெறுக',
    'Download daily history PDF': 'தினசரி வரலாற்று PDF பதிவிறக்குக',
    'Download weekly history PDF': 'வாராந்திர வரலாற்று PDF பதிவிறக்குக',
    'Try again': 'மீண்டும் முயற்சிக்கவும்',
    'Preview text': 'முன்னோட்ட உரை',
    'Add Another Caregiver': 'மற்றொரு பராமரிப்பாளரைச் சேர்க்கவும்',
    'Add Another Patient': 'மற்றொரு நோயாளரைச் சேர்க்கவும்',
    'Add Your First Medication': 'உங்கள் முதல் மருந்தைச் சேர்க்கவும்',
    'All': 'அனைத்தும்',
    'Answers to common DoseDiary questions':
        'பொதுவான DoseDiary கேள்விகளுக்கான பதில்கள்',
    'Caregiver / Carer': 'பராமரிப்பாளர்',
    'Caregiver account': 'பராமரிப்பாளர் கணக்கு',
    'Caregiver Full Name *': 'பராமரிப்பாளர் முழுப் பெயர் *',
    'Child / Dependent': 'குழந்தை / சார்ந்தவர்',
    'Clear read notifications': 'படித்த அறிவிப்புகளை அழிக்கவும்',
    'Cloud sync, local records, and PDF exports':
        'மேக ஒத்திசைவு, உள்ளூர் பதிவுகள் மற்றும் PDF ஏற்றுமதி',
    'Confirmed on Smart Cap': 'Smart Cap மூலம் உறுதிப்படுத்தப்பட்டது',
    'Could not load medication history': 'மருந்து வரலாற்றை ஏற்ற முடியவில்லை',
    'Could not save the history PDF. Try again.':
        'வரலாற்று PDF-ஐ சேமிக்க முடியவில்லை. மீண்டும் முயற்சிக்கவும்.',
    'Creating medication history PDF...':
        'மருந்து வரலாற்று PDF உருவாக்கப்படுகிறது...',
    'Daughter': 'மகள்',
    'Delete': 'நீக்கு',
    'Doctor / Physician': 'மருத்துவர்',
    'DoseDiary ID copied': 'DoseDiary ID நகலெடுக்கப்பட்டது',
    'Family Member': 'குடும்ப உறுப்பினர்',
    'Father': 'தந்தை',
    'Grandparent': 'தாத்தா / பாட்டி',
    'ID unavailable': 'ID கிடைக்கவில்லை',
    'Important information about using this app':
        'இந்த செயலியைப் பயன்படுத்துவது பற்றிய முக்கிய தகவல்',
    'Inventory levels and refill reminders':
        'இருப்பு அளவுகள் மற்றும் மறு நிரப்பல் நினைவூட்டல்கள்',
    'Manage device access used by DoseDiary':
        'DoseDiary பயன்படுத்தும் சாதன அணுகலை நிர்வகிக்கவும்',
    'Mark all read': 'அனைத்தையும் படித்ததாகக் குறிக்கவும்',
    'Medication history PDF downloaded successfully.':
        'மருந்து வரலாற்று PDF வெற்றிகரமாகப் பதிவிறக்கப்பட்டது.',
    'Mother': 'தாய்',
    'NEW': 'புதியது',
    'No active medications are available to view.':
        'பார்க்க செயலில் உள்ள மருந்துகள் இல்லை.',
    'No Medications Added Yet': 'இதுவரை மருந்துகள் சேர்க்கப்படவில்லை',
    'No Regimen Scheduled for Today': 'இன்று மருந்து முறை திட்டமிடப்படவில்லை',
    'Notification previews and data storage':
        'அறிவிப்பு முன்னோட்டங்கள் மற்றும் தரவு சேமிப்பு',
    'Nurse / Home Care': 'செவிலியர் / வீட்டு பராமரிப்பு',
    'Password, device access, and preference reset':
        'கடவுச்சொல், சாதன அணுகல் மற்றும் விருப்ப மீட்டமைப்பு',
    'Patient / Client': 'நோயாளர் / வாடிக்கையாளர்',
    'Patient account': 'நோயாளர் கணக்கு',
    'Patient Full Name *': 'நோயாளர் முழுப் பெயர் *',
    'PDF download canceled.': 'PDF பதிவிறக்கம் ரத்துசெய்யப்பட்டது.',
    'Photo, phone, birthday, gender, and email':
        'படம், தொலைபேசி, பிறந்த நாள், பாலினம் மற்றும் மின்னஞ்சல்',
    'Recent reminders and caregiver alerts':
        'சமீபத்திய நினைவூட்டல்கள் மற்றும் பராமரிப்பாளர் எச்சரிக்கைகள்',
    'Retry & Grace Period': 'மறுமுயற்சி மற்றும் சலுகைக் காலம்',
    'Review medication-taking patterns':
        'மருந்து எடுத்துக்கொள்ளும் முறைகளை மதிப்பாய்வு செய்யவும்',
    'Save & Add Caregiver': 'சேமித்து பராமரிப்பாளரைச் சேர்க்கவும்',
    'Save & Allocate Patient': 'சேமித்து நோயாளரை ஒதுக்கவும்',
    'Sign out of DoseDiary?': 'DoseDiary-இலிருந்து வெளியேறவா?',
    'Son': 'மகன்',
    'Sound, vibration, retries, and grace period':
        'ஒலி, அதிர்வு, மறுமுயற்சிகள் மற்றும் சலுகைக் காலம்',
    'Spouse': 'வாழ்க்கைத்துணை',
    'Spouse / Partner': 'வாழ்க்கைத்துணை / இணை',
    'Syncing patient medications…': 'நோயாளர் மருந்துகள் ஒத்திசைக்கப்படுகின்றன…',
    'Syncing today’s doses…': 'இன்றைய மருந்தளவுகள் ஒத்திசைக்கப்படுகின்றன…',
    'Text size, simpler wording, and language':
        'எழுத்து அளவு, எளிய சொற்கள் மற்றும் மொழி',
    'Unread': 'படிக்காதவை',
    'Version, licences, and app information':
        'பதிப்பு, உரிமங்கள் மற்றும் செயலி தகவல்',
    'View details': 'விவரங்களைக் காண்க',
    'Your DoseDiary ID': 'உங்கள் DoseDiary ID',
  },
};

/// DoseDiary localization using English source text as a stable lookup key.
class AppLocalizations {
  const AppLocalizations(this.locale);
  final Locale locale;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations) ??
        const AppLocalizations(Locale('en'));
  }

  static const delegate = _AppLocalizationsDelegate();

  String get appTitle => 'DoseDiary';
  String tr(String english) =>
      localizedText[locale.languageCode]?[english] ?? english;

  String get home => tr('Home');
  String get medications => tr('Medications');
  String get history => tr('History');
  String get settings => tr('Settings');
  String get taken => tr('Taken');
  String get missed => tr('Missed');
  String get skipped => tr('Skipped');
  String get pending => tr('Pending');
  String get overdue => tr('Overdue');
  String get snoozed => tr('Snoozed');
  String get logDose => "I've Taken It";
  String get snooze => tr('Snooze Reminder');
  String get skip => tr('Skip This Dose');
}

extension LocalizedBuildContext on BuildContext {
  String tr(String english) => AppLocalizations.of(this).tr(english);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      ['en', 'si', 'ta'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}
