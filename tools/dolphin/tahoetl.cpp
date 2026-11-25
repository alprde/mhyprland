// Dolphin'e macOS tarzı pencere düğmeleri ekleyen küçük Qt eklentisi (Hyprland'de başlık çubuğu yok).
// Araç çubuğunun başına, kenar çubuğu genişliğinde bir alan ekler: kırmızı = kapat, sarı = küçült, yeşil = tam ekran.
// Yalnızca "dolphin" sürecinde çalışır. Davranış Tahoe ayar uygulamasındaki düğmelerle aynıdır.
#include <QAction>
#include <QApplication>
#include <QEvent>
#include <QGenericPlugin>
#include <QHBoxLayout>
#include <QMainWindow>
#include <QProcess>
#include <QPointer>
#include <QPushButton>
#include <QStyle>
#include <QTimer>
#include <QToolBar>

static const int AREA_WIDTH = 182;   // kenar çubuğunun varsayılan genişliği: geri/ileri içerik alanının başında kalır

class Lights : public QWidget {
public:
    QList<QPushButton *> buttons;
    explicit Lights(QMainWindow *win) {
        setObjectName("tahoeTrafficLights");
        setFixedWidth(AREA_WIDTH);
        setAttribute(Qt::WA_Hover);
        auto *row = new QHBoxLayout(this);
        row->setContentsMargins(10, 0, 0, 0);
        row->setSpacing(9);
        add(row, "#ff5f57", QStringLiteral("×"), [win] { win->close(); });
        // komutlar etkin pencereye değil, bu sürecin penceresine gider
        const QString me = QStringLiteral("window = \"pid:%1\"").arg(QCoreApplication::applicationPid());
        add(row, "#febc2e", QStringLiteral("−"), [me] { hypr("hl.dsp.window.move({ workspace = \"special:minimized\", follow = false, " + me + " })"); });
        add(row, "#28c840", QStringLiteral("+"), [me] { hypr("hl.dsp.window.fullscreen({ " + me + " })"); });
        row->addStretch(1);
        paintButtons(false);
    }
    static void hypr(const QString &dispatch) {
        QProcess::startDetached("hyprctl", {"dispatch", dispatch});
    }
protected:
    bool event(QEvent *e) override {
        if (e->type() == QEvent::HoverEnter) paintButtons(true);
        if (e->type() == QEvent::HoverLeave) paintButtons(false);
        return QWidget::event(e);
    }
private:
    QStringList colors, signs;
    template <typename F> void add(QHBoxLayout *row, const char *color, const QString &sign, F action) {
        auto *b = new QPushButton(this);
        b->setFixedSize(14, 14);
        b->setFocusPolicy(Qt::NoFocus);
        QObject::connect(b, &QPushButton::clicked, this, action);
        row->addWidget(b, 0, Qt::AlignVCenter);
        buttons << b;
        colors << color;
        signs << sign;
    }
    void paintButtons(bool hover) {   // simgeler yalnızca imleç grubun üzerindeyken görünür (macOS gibi)
        for (int i = 0; i < buttons.size(); ++i) {
            buttons[i]->setText(hover ? signs[i] : QString());
            buttons[i]->setStyleSheet(QStringLiteral("QPushButton { background: %1; border: none; border-radius: 7px; padding: 0px;"
                                                     " min-width: 14px; max-width: 14px; min-height: 14px; max-height: 14px;"
                                                     " color: rgba(0,0,0,0.6); font-size: 12px; font-weight: 800; }").arg(colors[i]));
        }
    }
};

class Injector : public QObject {
public:
    using QObject::QObject;
    // Dolphin ana penceresini olay döngüsü başlamadan gösterir: o pencereler ayrıca taranır
    static void scan() {
        const auto widgets = QApplication::topLevelWidgets();
        for (QWidget *w : widgets)
            if (auto *win = qobject_cast<QMainWindow *>(w); win && win->inherits("DolphinMainWindow")) ensure(win);
    }
protected:
    bool eventFilter(QObject *obj, QEvent *e) override {
        // pencere gösterilince (ve araç çubuğu yeniden kurulunca) düğmelerin yerinde olduğundan emin ol
        if (e->type() == QEvent::Show || e->type() == QEvent::ActionAdded) {
            auto *bar = qobject_cast<QToolBar *>(obj);
            QMainWindow *win = bar ? qobject_cast<QMainWindow *>(bar->parentWidget()) : qobject_cast<QMainWindow *>(obj);
            if (win && win->inherits("DolphinMainWindow")) {
                QPointer<QMainWindow> guard(win);
                QTimer::singleShot(0, win, [guard] { if (guard) ensure(guard); });
            }
        }
        return false;
    }
private:
    // araç çubuğu düğmelerine eylem adından kimlik ver (ör. "tl_go_back"): stil dosyası düğme yazısına, yani dile bağlı kalmaz
    static void nameButtons(QToolBar *bar) {
        const auto actions = bar->actions();
        for (QAction *a : actions) {
            QWidget *w = bar->widgetForAction(a);
            const QString id = QStringLiteral("tl_") + a->objectName();
            if (!w || a->objectName().isEmpty() || !w->inherits("QToolButton") || w->objectName() == id) continue;
            w->setObjectName(id);
            w->style()->unpolish(w);
            w->style()->polish(w);
        }
    }
    static void ensure(QMainWindow *win) {
        auto *bar = win->findChild<QToolBar *>("mainToolBar");
        if (!bar || bar->actions().isEmpty()) return;
        nameButtons(bar);
        if (bar->findChild<QWidget *>("tahoeTrafficLights")) return;
        auto *lights = new Lights(win);
        bar->insertWidget(bar->actions().constFirst(), lights);
        // yalnızca sınama: TAHOE_TL_TEST=0|1|2 → ilgili düğmeye 2,5 sn sonra kendiliğinden bas
        bool ok = false;
        int n = qEnvironmentVariableIntValue("TAHOE_TL_TEST", &ok);
        if (ok && n >= 0 && n < lights->buttons.size())
            QTimer::singleShot(2500, lights->buttons[n], &QPushButton::click);
    }
};

class TahoeTrafficLightsPlugin : public QGenericPlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID "org.qt-project.Qt.QGenericPluginFactoryInterface" FILE "tahoetl.json")
public:
    QObject *create(const QString &key, const QString &) override {
        if (key.compare("tahoetl", Qt::CaseInsensitive) != 0) return nullptr;
        // Dolphin'den açılan programlara bu değişken geçmesin
        qunsetenv("QT_QPA_GENERIC_PLUGINS");
        auto *injector = new Injector;
        QTimer::singleShot(0, injector, [injector] {
            if (QCoreApplication::applicationName() != "dolphin") return;
            qApp->installEventFilter(injector);
            Injector::scan();
            QTimer::singleShot(500, injector, [] { Injector::scan(); });
        });
        return injector;
    }
};
#include "tahoetl.moc"
