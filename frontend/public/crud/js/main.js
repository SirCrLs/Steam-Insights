import { loadPage, changeEntity, initQueryForm } from '/crud/js/services/table-manager.js';

document.querySelectorAll('[data-entity]').forEach(element => {
  element.addEventListener('click', (e) => {
    const entity = element.getAttribute('data-entity');

    document.querySelectorAll('.tab-btn, .dropdown-item').forEach(btn => {
      btn.classList.remove('active');
    });

    element.classList.add('active');

    const dropdownDetails = element.closest('.dropdown-details');
    if (dropdownDetails) {
      const summaryBtn = dropdownDetails.querySelector('.dropdown-toggle');
      if (summaryBtn) summaryBtn.classList.add('active');
    }

    changeEntity(entity);
  });
});

initQueryForm();

loadPage(1);