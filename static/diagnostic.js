// 🔍 اسکریپت دیاگنوستیک Fionex
console.clear();
console.log('%c🔍 Fionex Diagnostic Report', 'font-size:16px;font-weight:bold;color:#00aa00;');
console.log('═'.repeat(60));

// ۱. بررسی بارگذاری کتابخانه‌ها
console.group('📚 کتابخانه‌های بارگذاری شده');
try {
    console.log('Chart.js وجود دارد؟', typeof Chart !== 'undefined' ? '✅' : '❌');
    console.log('Fetch API وجود دارد؟', typeof fetch !== 'undefined' ? '✅' : '❌');
} catch(e) {
    console.error('خطا در بررسی کتابخانه‌ها:', e);
}
console.groupEnd();

// ۲. بررسی DOM Elements
console.group('🏗️ عناصر DOM');
const requiredElements = [
    'tab1', 'tab2', 'tab3', 'tab4',
    'dashboard-overview', 'gold-dollar-analysis',
    'correlation-analysis', 'backtest-validation'
];
requiredElements.forEach(id => {
    const elem = document.getElementById(id);
    console.log(id + ':', elem ? '✅' : '❌');
});
console.groupEnd();

// ۳. بررسی تابع‌های اصلی
console.group('⚙️ توابع جاوااسکریپت');
console.log('FionexApp:', typeof FionexApp !== 'undefined' ? '✅ تعریف شده' : '❌ تعریف نشده');
if (typeof FionexApp !== 'undefined') {
    console.log('  - init:', typeof FionexApp.init);
    console.log('  - loadData:', typeof FionexApp.loadData);
    console.log('  - switchTab:', typeof FionexApp.switchTab);
}
console.groupEnd();

// ۴. تست API
console.group('🌐 اتصال API');
fetch('/api/data')
    .then(r => r.json())
    .then(data => {
        console.log('✅ API پاسخ داد');
        console.log('کلیدهای داده:', Object.keys(data));
        console.log('داده‌ها:', data);
    })
    .catch(e => console.error('❌ API خطا:', e));
console.groupEnd();

console.log('═'.repeat(60));
console.log('%cپایان گزارش دیاگنوستیک', 'color:#ff6600;');