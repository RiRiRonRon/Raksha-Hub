#include <QApplication>
#include <QQmlApplicationEngine>
#include <QQuickWindow>
#include <QSGRendererInterface>
#include <QIcon>

int main(int argc, char *argv[])
{

    QCoreApplication::setAttribute(Qt::AA_UseDesktopOpenGL);


    QQuickWindow::setGraphicsApi(QSGRendererInterface::OpenGL);

    QApplication app(argc, argv);
    app.setWindowIcon(QIcon(":/src/app.ico"));

    QQmlApplicationEngine engine;
    QObject::connect(
        &engine,
        &QQmlApplicationEngine::objectCreationFailed,
        &app,
        []() { QCoreApplication::exit(-1); },
        Qt::QueuedConnection);

    engine.loadFromModule("Raksha_Hub", "Main");
    return QGuiApplication::exec();
}