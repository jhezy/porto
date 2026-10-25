<script setup>
import { ref, onMounted } from "vue";
import { supabase } from "../../lib/supabase";

const experiences = ref([]);
const loading = ref(true);
const saving = ref(false);
const deletingId = ref(null);
const errorMessage = ref("");
const successMessage = ref("");
const showForm = ref(false);
const editingId = ref(null);

const emptyForm = () => ({
  role: "",
  organization: "",
  employment_type: "Full-time",
  location: "",
  description: "",
  start_date: "",
  end_date: "",
  is_current: false,
  sort_order: 0,
  is_visible: true,
  is_published: true,
});

const form = ref(emptyForm());

const employmentTypes = [
  "Full-time",
  "Part-time",
  "Contract",
  "Freelance",
  "Internship",
  "Self-employed",
];

function formatDate(value) {
  if (!value) return "Sekarang";

  return new Date(`${value}T00:00:00`).toLocaleDateString("id-ID", {
    month: "short",
    year: "numeric",
  });
}

function formatPeriod(item) {
  return `${formatDate(item.start_date)} — ${
    item.is_current ? "Sekarang" : formatDate(item.end_date)
  }`;
}

async function loadExperiences() {
  loading.value = true;
  errorMessage.value = "";

  try {
    if (!supabase) {
      throw new Error("Supabase belum dikonfigurasi.");
    }

    const { data, error } = await supabase
      .from("experiences")
      .select("*")
      .order("sort_order", { ascending: true })
      .order("start_date", { ascending: false });

    if (error) throw error;

    experiences.value = data || [];
  } catch (error) {
    errorMessage.value = error.message || "Gagal memuat pengalaman.";
  } finally {
    loading.value = false;
  }
}

function openCreateForm() {
  editingId.value = null;
  form.value = emptyForm();
  errorMessage.value = "";
  successMessage.value = "";
  showForm.value = true;
}

function openEditForm(item) {
  editingId.value = item.id;

  form.value = {
    ...emptyForm(),
    ...item,
    start_date: item.start_date || "",
    end_date: item.end_date || "",
  };

  errorMessage.value = "";
  successMessage.value = "";
  showForm.value = true;
}

function closeForm() {
  showForm.value = false;
  editingId.value = null;
}

async function saveExperience() {
  if (!form.value.role.trim() || !form.value.organization.trim()) {
    errorMessage.value = "Posisi dan organisasi wajib diisi.";
    return;
  }

  if (!form.value.start_date) {
    errorMessage.value = "Tanggal mulai wajib diisi.";
    return;
  }

  if (
    !form.value.is_current &&
    form.value.end_date &&
    form.value.end_date < form.value.start_date
  ) {
    errorMessage.value = "Tanggal selesai tidak boleh sebelum tanggal mulai.";
    return;
  }

  saving.value = true;
  errorMessage.value = "";
  successMessage.value = "";

  const payload = {
    role: form.value.role.trim(),
    organization: form.value.organization.trim(),
    employment_type: form.value.employment_type || null,
    location: form.value.location.trim() || null,
    description: form.value.description.trim() || null,
    start_date: form.value.start_date || null,
    end_date: form.value.is_current ? null : form.value.end_date || null,
    is_current: form.value.is_current,
    sort_order: Number(form.value.sort_order) || 0,
    is_visible: form.value.is_visible,
    is_published: form.value.is_published,
    updated_at: new Date().toISOString(),
  };

  try {
    if (!supabase) {
      throw new Error("Supabase belum dikonfigurasi.");
    }

    if (editingId.value) {
      const { data, error } = await supabase
        .from("experiences")
        .update(payload)
        .eq("id", editingId.value)
        .select("id");

      if (error) throw error;
      if (!data?.length) {
        throw new Error(
          "Data tidak berubah. Periksa izin update atau pastikan data tersedia.",
        );
      }

      successMessage.value = "Pengalaman berhasil diperbarui.";
    } else {
      const { data, error } = await supabase
        .from("experiences")
        .insert(payload)
        .select("id");

      if (error) throw error;
      if (!data?.length) {
        throw new Error(
          "Data tidak berhasil dikonfirmasi. Periksa izin insert.",
        );
      }

      successMessage.value = "Pengalaman berhasil ditambahkan.";
    }

    closeForm();
    await loadExperiences();
  } catch (error) {
    errorMessage.value = error.message || "Gagal menyimpan pengalaman.";
  } finally {
    saving.value = false;
  }
}

async function deleteExperience(item) {
  const confirmed = window.confirm(
    `Hapus pengalaman "${item.role}" di ${item.organization}?`,
  );

  if (!confirmed) return;

  deletingId.value = item.id;
  errorMessage.value = "";
  successMessage.value = "";

  try {
    const { data, error } = await supabase
      .from("experiences")
      .delete()
      .eq("id", item.id)
      .select("id");

    if (error) throw error;

    if (!data?.length) {
      throw new Error(
        "Data tidak terhapus. Periksa izin delete pada kebijakan RLS.",
      );
    }

    experiences.value = experiences.value.filter(
      (experience) => experience.id !== item.id,
    );

    successMessage.value = "Pengalaman berhasil dihapus.";
  } catch (error) {
    errorMessage.value = error.message || "Gagal menghapus pengalaman.";
  } finally {
    deletingId.value = null;
  }
}

onMounted(loadExperiences);
</script>

<template>
  <section class="experience-admin">
    <div
      class="d-flex flex-wrap align-items-center justify-content-between gap-3 mb-4"
    >
      <div>
        <div class="text-accent small fw-semibold mb-1">
          WORKSPACE / PENGALAMAN
        </div>
        <h1 class="h3 fw-bold mb-1">Pengalaman Kerja</h1>
        <p class="text-muted-custom mb-0">
          Kelola perjalanan karier yang ditampilkan di portfolio.
        </p>
      </div>

      <button
        class="btn btn-accent"
        @click="openCreateForm"
      >
        <i class="bi bi-plus-lg me-2"></i>Tambah Pengalaman
      </button>
    </div>

    <div
      v-if="errorMessage"
      class="alert alert-danger"
      role="alert"
    >
      {{ errorMessage }}
    </div>

    <div
      v-if="successMessage"
      class="alert alert-success"
      role="status"
    >
      {{ successMessage }}
    </div>

    <div class="experience-summary mb-4">
      <div class="experience-stat">
        <span class="text-muted-custom small">Total Pengalaman</span>
        <strong>{{ experiences.length }}</strong>
      </div>

      <div class="experience-stat">
        <span class="text-muted-custom small">Dipublikasikan</span>
        <strong>
          {{ experiences.filter((item) => item.is_published).length }}
        </strong>
      </div>

      <div class="experience-stat">
        <span class="text-muted-custom small">Pekerjaan Saat Ini</span>
        <strong>
          {{ experiences.filter((item) => item.is_current).length }}
        </strong>
      </div>
    </div>

    <div class="experience-panel">
      <div class="d-flex align-items-center justify-content-between mb-3">
        <h2 class="h6 fw-bold mb-0">Daftar Pengalaman</h2>

        <button
          class="btn btn-sm btn-outline-soft"
          @click="loadExperiences"
          :disabled="loading"
        >
          <i class="bi bi-arrow-clockwise me-1"></i>Muat ulang
        </button>
      </div>

      <div
        v-if="loading"
        class="py-5 text-center text-muted-custom"
      >
        <div class="spinner-border spinner-border-sm me-2"></div>
        Memuat pengalaman...
      </div>

      <div
        v-else-if="experiences.length === 0"
        class="experience-empty text-center py-5"
      >
        <i class="bi bi-briefcase fs-1 text-accent"></i>
        <h3 class="h6 fw-bold mt-3">Belum ada pengalaman</h3>
        <p class="text-muted-custom small">
          Tambahkan pengalaman kerja pertamamu.
        </p>
        <button
          class="btn btn-accent btn-sm"
          @click="openCreateForm"
        >
          Tambah Pengalaman
        </button>
      </div>

      <div
        v-else
        class="table-responsive"
      >
        <table class="table experience-table align-middle mb-0">
          <thead>
            <tr>
              <th>Posisi / Organisasi</th>
              <th>Periode</th>
              <th>Status</th>
              <th class="text-end">Aksi</th>
            </tr>
          </thead>

          <tbody>
            <tr
              v-for="item in experiences"
              :key="item.id"
            >
              <td>
                <div class="fw-semibold">{{ item.role }}</div>
                <div class="text-muted-custom small">
                  {{ item.organization }}
                  <span v-if="item.location"> · {{ item.location }}</span>
                </div>
              </td>

              <td>
                <div class="small">{{ formatPeriod(item) }}</div>
                <div class="text-muted-custom small">
                  {{ item.employment_type || "Tidak ditentukan" }}
                </div>
              </td>

              <td>
                <span
                  class="experience-badge"
                  :class="item.is_published ? 'is-published' : 'is-draft'"
                >
                  {{ item.is_published ? "Published" : "Draft" }}
                </span>

                <span
                  v-if="!item.is_visible"
                  class="experience-badge is-hidden ms-1"
                >
                  Tersembunyi
                </span>

                <span
                  v-if="item.is_current"
                  class="experience-badge is-current ms-1"
                >
                  Saat ini
                </span>
              </td>

              <td>
                <div class="d-flex justify-content-end gap-2">
                  <button
                    class="btn btn-sm btn-outline-soft"
                    title="Edit"
                    @click="openEditForm(item)"
                  >
                    <i class="bi bi-pencil"></i>
                  </button>

                  <button
                    class="btn btn-sm btn-outline-danger"
                    title="Hapus"
                    :disabled="deletingId === item.id"
                    @click="deleteExperience(item)"
                  >
                    <span
                      v-if="deletingId === item.id"
                      class="spinner-border spinner-border-sm"
                    ></span>
                    <i
                      v-else
                      class="bi bi-trash3"
                    ></i>
                  </button>
                </div>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>

    <div
      v-if="showForm"
      class="experience-modal-backdrop"
      @click.self="closeForm"
    >
      <div
        class="experience-modal"
        role="dialog"
        aria-modal="true"
        aria-labelledby="experience-form-title"
      >
        <div
          class="d-flex align-items-center justify-content-between gap-3 mb-4"
        >
          <div>
            <h2
              id="experience-form-title"
              class="h5 fw-bold mb-1"
            >
              {{ editingId ? "Edit Pengalaman" : "Tambah Pengalaman" }}
            </h2>
            <p class="text-muted-custom small mb-0">
              Isi informasi pengalaman kerja.
            </p>
          </div>

          <button
            class="btn btn-sm btn-outline-soft"
            aria-label="Tutup formulir"
            @click="closeForm"
          >
            <i class="bi bi-x-lg"></i>
          </button>
        </div>

        <form @submit.prevent="saveExperience">
          <div class="row g-3">
            <div class="col-md-6">
              <label class="form-label">Posisi *</label>
              <input
                v-model="form.role"
                class="form-control admin-input"
                required
                maxlength="150"
                placeholder="Web Developer"
              />
            </div>

            <div class="col-md-6">
              <label class="form-label">Organisasi / Perusahaan *</label>
              <input
                v-model="form.organization"
                class="form-control admin-input"
                required
                maxlength="150"
                placeholder="Nama perusahaan atau organisasi"
              />
            </div>

            <div class="col-md-6">
              <label class="form-label">Tipe Pekerjaan</label>
              <select
                v-model="form.employment_type"
                class="form-select admin-input"
              >
                <option value="">Pilih tipe pekerjaan</option>
                <option
                  v-for="type in employmentTypes"
                  :key="type"
                  :value="type"
                >
                  {{ type }}
                </option>
              </select>
            </div>

            <div class="col-md-6">
              <label class="form-label">Lokasi</label>
              <input
                v-model="form.location"
                class="form-control admin-input"
                placeholder="Jakarta / Remote"
              />
            </div>

            <div class="col-md-6">
              <label class="form-label">Tanggal Mulai *</label>
              <input
                v-model="form.start_date"
                type="date"
                class="form-control admin-input"
                required
              />
            </div>

            <div class="col-md-6">
              <label class="form-label">Tanggal Selesai</label>
              <input
                v-model="form.end_date"
                type="date"
                class="form-control admin-input"
                :disabled="form.is_current"
                :min="form.start_date || undefined"
              />
            </div>

            <div class="col-12">
              <div class="form-check">
                <input
                  id="isCurrentExperience"
                  v-model="form.is_current"
                  class="form-check-input"
                  type="checkbox"
                  @change="form.is_current && (form.end_date = '')"
                />
                <label
                  class="form-check-label"
                  for="isCurrentExperience"
                >
                  Saya masih bekerja di sini
                </label>
              </div>
            </div>

            <div class="col-12">
              <label class="form-label">Deskripsi</label>
              <textarea
                v-model="form.description"
                class="form-control admin-input"
                rows="4"
                placeholder="Jelaskan tanggung jawab, pencapaian, atau pekerjaan yang dilakukan..."
              ></textarea>
            </div>

            <div class="col-md-6">
              <label class="form-label">Urutan Tampilan</label>
              <input
                v-model.number="form.sort_order"
                type="number"
                min="0"
                class="form-control admin-input"
              />
              <div class="form-text">
                Angka lebih kecil tampil lebih dahulu.
              </div>
            </div>

            <div class="col-md-6">
              <div class="form-check mt-3">
                <input
                  id="visibleExperience"
                  v-model="form.is_visible"
                  class="form-check-input"
                  type="checkbox"
                />
                <label
                  class="form-check-label"
                  for="visibleExperience"
                >
                  Tampilkan di portfolio
                </label>
              </div>

              <div class="form-check mt-2">
                <input
                  id="publishExperience"
                  v-model="form.is_published"
                  class="form-check-input"
                  type="checkbox"
                />
                <label
                  class="form-check-label"
                  for="publishExperience"
                >
                  Status publikasi aktif
                </label>
              </div>
            </div>
          </div>

          <div
            v-if="errorMessage"
            class="alert alert-danger mt-3 mb-0"
          >
            {{ errorMessage }}
          </div>

          <div class="d-flex justify-content-end gap-2 mt-4">
            <button
              type="button"
              class="btn btn-outline-soft"
              :disabled="saving"
              @click="closeForm"
            >
              Batal
            </button>

            <button
              type="submit"
              class="btn btn-accent"
              :disabled="saving"
            >
              <span
                v-if="saving"
                class="spinner-border spinner-border-sm me-2"
              ></span>
              {{ saving ? "Menyimpan..." : "Simpan Pengalaman" }}
            </button>
          </div>
        </form>
      </div>
    </div>
  </section>
</template>

<style scoped>
.experience-admin {
  color: var(--text-primary, #edf4f3);
}

.experience-summary {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 1rem;
}

.experience-stat,
.experience-panel {
  background: var(--surface, #151d20);
  border: 1px solid var(--border-color, rgba(255, 255, 255, 0.08));
  border-radius: 16px;
}

.experience-stat {
  display: flex;
  flex-direction: column;
  gap: 0.5rem;
  padding: 1.25rem;
}

.experience-stat strong {
  font-size: 1.75rem;
}

.experience-panel {
  padding: 1.25rem;
  min-width: 0;
}

.experience-table {
  --bs-table-bg: transparent;
  --bs-table-color: var(--text-primary, #edf4f3);
  --bs-table-border-color: var(--border-color, rgba(255, 255, 255, 0.08));
}

.experience-table th {
  color: var(--text-muted, #9baead);
  font-size: 0.75rem;
  text-transform: uppercase;
  letter-spacing: 0.06em;
  white-space: nowrap;
}

.experience-table td {
  padding-top: 1rem;
  padding-bottom: 1rem;
}

.experience-badge {
  display: inline-block;
  padding: 0.3rem 0.55rem;
  border-radius: 999px;
  font-size: 0.72rem;
  font-weight: 600;
  white-space: nowrap;
}

.is-published {
  color: #8ee6c9;
  background: rgba(45, 190, 145, 0.12);
}

.is-draft {
  color: #f3d18a;
  background: rgba(240, 180, 60, 0.12);
}

.is-current {
  color: #9bdcfb;
  background: rgba(70, 165, 220, 0.12);
}

.is-hidden {
  color: #f1b3b3;
  background: rgba(220, 70, 70, 0.12);
}

.experience-modal-backdrop {
  position: fixed;
  inset: 0;
  z-index: 1055;
  display: flex;
  align-items: center;
  justify-content: center;
  padding: 1rem;
  background: rgba(0, 0, 0, 0.7);
  overflow-y: auto;
}

.experience-modal {
  width: min(760px, 100%);
  max-height: calc(100dvh - 2rem);
  overflow-y: auto;
  padding: 1.5rem;
  border: 1px solid var(--border-color, rgba(255, 255, 255, 0.1));
  border-radius: 18px;
  background: var(--surface, #151d20);
  color: var(--text-primary, #edf4f3);
  box-shadow: 0 24px 80px rgba(0, 0, 0, 0.4);
}

.experience-modal .form-label,
.experience-modal .form-check-label {
  font-size: 0.875rem;
}

.experience-modal .admin-input {
  color-scheme: dark;
}

@media (max-width: 767.98px) {
  .experience-summary {
    grid-template-columns: 1fr;
    gap: 0.75rem;
  }

  .experience-stat {
    padding: 1rem;
  }

  .experience-stat strong {
    font-size: 1.4rem;
  }

  .experience-panel {
    padding: 0.85rem;
  }

  .experience-modal {
    padding: 1rem;
  }
}
</style>
